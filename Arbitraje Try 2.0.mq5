//+------------------------------------------------------------------+
//|                                 Arbitraje Triangular UNIFICADO.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "A. D. A."
#property link      ""
#property version   "1.20"
#property description " Arbitraje. Sistema de comercio de bajo riesgo."
#property description "1: EA usa un número mágico desde el menú de entrada hasta +200"
#property description "2: Todo el registro se escribe en el archivo: Control de arbitraje de tres puntos YYYY.MM.DD.csv"
#property description "3: Antes de realizar la prueba, debe crear un archivo con símbolos"
#property description "4: Para el modo de demostración, utilice el triángulo de forma predeterminada: EURUSD+GBPUSD+EURGBP"
//#property icon "\\Images\\arbitraje.ico"
extern color   background_color = Teal; // Color de fondo de información
#property strict

// macros
#define DEVIATION       3                                      // deslizamiento máximo
#define FILENAME        "Arbitrage T UNID.csv"            // los símbolos para el trabajo se almacenan aquí
#define FILELOG         "Arbitrage Control T UNID"       // parte del archivo de registro
#define FILEOPENWRITE(nm)  FileOpen(nm,FILE_UNICODE|FILE_WRITE|FILE_SHARE_READ|FILE_CSV)  // abrir archivo para escribir
#define FILEOPENREAD(nm)   FileOpen(nm,FILE_UNICODE|FILE_READ|FILE_SHARE_READ|FILE_CSV)   // abrir archivo para leer
#define CF              1.3                                    // mayor margen
#define MAGIC           200                                    // gama de magos utilizados
#define MAXTIMEWAIT     3                                      // tiempo máximo para esperar que un triángulo se abra en segundos
#define PAUSESECUND     600                                    // pausa para volver a abrir el triángulo si la apertura anterior fue un error
                            
 // Parámetros de entrada

      

//extern string modo_trabajo=" 0 simbolos del mercado, 1 simbolos de archivo, 2 crear archivos de triangulaciones, 3 no abrir espera ganancias ";
enum enMode
   {
      STANDART_MODE  =  0, /*Símbolos del mercado*/                  // Modo normal. Símbolos de la Observación del mercado
      USE_FILE       =  1, /*Símbolos del archivo*/                          // Usar el archivo de símbolos
      CREATE_FILE    =  2, /*Crear archivo con símbolos*/                   // Crear el archivo para el Probador o para el trabajo
      //END_ADN_CLOSE  =  3, /*No abrir, esperar ganancias, cerrar y salir*/      // Cerrar todas sus transacciones y terminar el trabajo
      //CLOSE_ONLY     =  4  /*No abrir, no esperar ganancias, cerrar y salir*/
   };

input       enMode     inMode=     1;          // Modo de trabajo

input       double      inProfit=   2.5;          // Comisión
input       double      inLot=      0.01;       // Volumen comercial
input       ushort      inMaxThree= 3;          //Together triangles open
input      int         inMagic=    300;        //EA number
input      string      inCmnt=     "Arbitraje T ";       //Comment
input      bool        inUseIA=    true;       // Activar filtro adaptativo (IA)
input      double      inAIAgressividad=0.35;  // 0.0 a 1.0, sensibilidad del filtro IA
input      bool        inUseNeuralNet=true;    // Activar red neuronal
input      int         inNNTrainingDays=90;    // Días históricos para entrenamiento
input      ENUM_TIMEFRAMES inNNTimeframe=PERIOD_M15; // Timeframe intradía
input      int         inNNEpochs=4;           // Épocas de entrenamiento
input      double      inNNLearningRate=0.03;  // Learning rate
input      double      inNNBuyThreshold=0.56;  // Umbral probabilidad compra
input      double      inNNSellThreshold=0.44; // Umbral probabilidad venta
input      bool        inUseMMMethod=true;     // Filtro Market Maker


int         glAccountsType=0; // tipo de cuenta. cobertura o red
int         glFileLog=0;      // manejar el archivo de registro
string      glPanelBgName="ARB_PANEL_BG";
string      glPanelTextName="ARB_PANEL_TEXT";

double      glNNWeights[6]={0.0,0.15,-0.08,0.12,0.10,-0.05};
bool        glNNReady=false;
datetime    glNNLastTrain=0;


#ifndef SELECT_BY_POS
#define SELECT_BY_POS 0
#endif
#ifndef SELECT_BY_TICKET
#define SELECT_BY_TICKET 1
#endif
#ifndef MODE_TRADES
#define MODE_TRADES 0
#endif
#ifndef MODE_MARGINREQUIRED
#define MODE_MARGINREQUIRED 32
#endif
#ifndef OP_BUY
#define OP_BUY 0
#endif
#ifndef OP_SELL
#define OP_SELL 1
#endif

ulong glSelectedTicket=0;
bool  glSelectedIsPosition=false;

double MarketInfo(string symbol,int mode)
  {
   if(mode==MODE_MARGINREQUIRED)
     {
      double margin=0.0;
      if(SymbolInfoDouble(symbol,SYMBOL_MARGIN_INITIAL,margin) && margin>0.0)
         return(margin);

      double ask=0.0,contract_size=0.0;
      long leverage=AccountInfoInteger(ACCOUNT_LEVERAGE);
      SymbolInfoDouble(symbol,SYMBOL_ASK,ask);
      SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE,contract_size);
      if(leverage<=0) leverage=1;
      return((ask*contract_size)/(double)leverage);
     }
   return(0.0);
  }

bool OrderSelect(int index,int select,int pool)
  {
   glSelectedTicket=0;
   glSelectedIsPosition=false;

   if(select==SELECT_BY_POS)
     {
      if(index>=0 && index<PositionsTotal())
        {
         ulong pt=PositionGetTicket(index);
         if(pt>0 && PositionSelectByTicket(pt))
           {
            glSelectedTicket=pt;
            glSelectedIsPosition=true;
            return(true);
           }
        }

      if(index>=0 && index<OrdersTotal())
        {
         ulong ot=OrderGetTicket(index);
         if(ot>0 && ::OrderSelect(ot))
           {
            glSelectedTicket=ot;
            glSelectedIsPosition=false;
            return(true);
           }
        }
      return(false);
     }

   if(select==SELECT_BY_TICKET)
     {
      ulong t=(ulong)index;
      if(PositionSelectByTicket(t))
        {
         glSelectedTicket=t;
         glSelectedIsPosition=true;
         return(true);
        }
      if(::OrderSelect(t))
        {
         glSelectedTicket=t;
         glSelectedIsPosition=false;
         return(true);
        }
     }
   return(false);
  }

int OrderMagicNumber()
  {
   if(glSelectedTicket==0) return(0);
   if(glSelectedIsPosition)
      return((int)PositionGetInteger(POSITION_MAGIC));
   return((int)OrderGetInteger(ORDER_MAGIC));
  }

string OrderSymbol()
  {
   if(glSelectedTicket==0) return("");
   if(glSelectedIsPosition)
      return(PositionGetString(POSITION_SYMBOL));
   return(OrderGetString(ORDER_SYMBOL));
  }

int OrderTicket()
  {
   return((int)glSelectedTicket);
  }

datetime OrderCloseTime()
  {
   if(glSelectedTicket==0) return(0);
   if(glSelectedIsPosition) return(0);
   return((datetime)OrderGetInteger(ORDER_TIME_DONE));
  }

double OrderProfit()
  {
   if(glSelectedTicket==0) return(0.0);
   if(glSelectedIsPosition)
      return(PositionGetDouble(POSITION_PROFIT));
   return(0.0);
  }

datetime OrderOpenTime()
  {
   if(glSelectedTicket==0) return(0);
   if(glSelectedIsPosition)
      return((datetime)PositionGetInteger(POSITION_TIME));
   return((datetime)OrderGetInteger(ORDER_TIME_SETUP));
  }

int OrderType()
  {
   if(glSelectedTicket==0) return(-1);
   if(glSelectedIsPosition)
     {
      ENUM_POSITION_TYPE ptype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype==POSITION_TYPE_BUY) return(OP_BUY);
      if(ptype==POSITION_TYPE_SELL) return(OP_SELL);
      return(-1);
     }

   ENUM_ORDER_TYPE otype=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   if(otype==ORDER_TYPE_BUY) return(OP_BUY);
   if(otype==ORDER_TYPE_SELL) return(OP_SELL);
   return(-1);
  }

double OrderLots()
  {
   if(glSelectedTicket==0) return(0.0);
   if(glSelectedIsPosition)
      return(PositionGetDouble(POSITION_VOLUME));
   return(OrderGetDouble(ORDER_VOLUME_CURRENT));
  }

bool OrderClose(int ticket,double lots,double price,int slippage)
  {
   ulong t=(ulong)ticket;
   if(!PositionSelectByTicket(t))
      return(false);

   string symbol=PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE ptype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action=TRADE_ACTION_DEAL;
   req.position=t;
   req.symbol=symbol;
   req.volume=lots;
   req.deviation=slippage;
   req.price=price;
   req.type=(ptype==POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   req.type_filling=ORDER_FILLING_IOC;

   if(!OrderSend(req,res))
      return(false);

   return(res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_PLACED);
  }


int OrderSend(string symbol,int cmd,double volume,double price,int slippage,double stoploss,double takeprofit,string comment="",int magic=0,datetime expiration=0,color arrow_color=clrNONE)
  {
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action=TRADE_ACTION_DEAL;
   req.symbol=symbol;
   req.volume=volume;
   req.deviation=slippage;
   req.magic=magic;
   req.comment=comment;
   req.price=price;

   if(cmd==OP_BUY)
      req.type=ORDER_TYPE_BUY;
   else
   if(cmd==OP_SELL)
      req.type=ORDER_TYPE_SELL;
   else
      return(-1);

   if(stoploss>0.0) req.sl=stoploss;
   if(takeprofit>0.0) req.tp=takeprofit;

   ENUM_SYMBOL_TRADE_EXECUTION exec_mode=(ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE);
   if(exec_mode==SYMBOL_TRADE_EXECUTION_EXCHANGE || exec_mode==SYMBOL_TRADE_EXECUTION_INSTANT || exec_mode==SYMBOL_TRADE_EXECUTION_REQUEST)
      req.type_filling=ORDER_FILLING_FOK;
   else
      req.type_filling=ORDER_FILLING_IOC;

   if(expiration>0)
     {
      req.type_time=ORDER_TIME_SPECIFIED;
      req.expiration=expiration;
     }

   if(!::OrderSend(req,res))
      return(-1);

   if(res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_PLACED || res.retcode==TRADE_RETCODE_DONE_PARTIAL)
      return((int)res.order);

   return(-1);
  }



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      Print("EA is a multicurrency and tester mode is not supported");
      Comment("EA is a multicurrency and tester mode is not supported");
      ExpertRemove();
      return(INIT_FAILED);
     }

   Print("===============================================\nStart EA: "+MQLInfoString(MQL_PROGRAM_NAME));

   fnWarning(inLot,glFileLog);                      //varias comprobaciones durante el lanzamiento del robot
   fnSetThree(MxThree,inMode);                        //triángulos compuestos
   fnChangeThree(MxThree);                            //los colocó correctamente
   fnSmbLoad(inLot,MxThree);                          //descargó el resto de los datos de cada personaje

   if(inMode==CREATE_FILE) //si solo necesita crear un archivo de caracteres para el trabajo o un probador
     {
      // elimine el archivo si es así.
      FileDelete(FILENAME);
      int fh=FILEOPENWRITE(FILENAME);
      if(fh==INVALID_HANDLE)
        {
         Alert("File with symbols not created");
         ExpertRemove();
        }
      // escribir triángulos y alguna información adicional en un archivo
      fnCreateFileSymbols(MxThree,fh);
      Print("File with symbols created");

      // cierre el archivo y salga del experto
      FileClose(fh);
      ExpertRemove();
     }

   if(glFileLog!=INVALID_HANDLE) //en el archivo de registro escriba los caracteres utilizados
      fnCreateFileSymbols(MxThree,glFileLog);

   fnRestart(MxThree,inMagic);                     //restaurar triángulos después de reiniciar el robot
   if(inUseNeuralNet)
      fnTrainNN90Days(MxThree);

   if(ArraySize(MxThree)<=0)
     {
      Print("Todos los triángulos usados: 0");
      return(INIT_FAILED);
     }
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   fnDeletePanel();
   FileClose(glFileLog);
   Print("Stop EA: "+MQLInfoString(MQL_PROGRAM_NAME)+"\n===============================================");
   Comment("");
   EventKillTimer();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(inUseNeuralNet && (TimeCurrent()-glNNLastTrain)>43200)
      fnTrainNN90Days(MxThree);

// primero, cuente el número de triángulos abiertos. Esto ahorrará significativamente recursos de la computadora.
// porque Si hay una restricción y la hemos alcanzado, entonces no consideramos el deslizamiento, etc.      

   ushort OpenThree=0;  // número de triángulos abiertos
   for(int j=ArraySize(MxThree)-1;j>=0;j--)
      if(MxThree[j].status!=0) OpenThree++; //también consideramos cerrado, porque pueden colgarse durante mucho tiempo, pero de todos modos se consideran

   if(DayOfWeek()==5 && Hour()>=15); else   //jueves después de las 18 no abren
     {
      if(inMaxThree==0 || (inMaxThree>0 && inMaxThree>OpenThree))
         fnCalcDelta(MxThree,inProfit,inCmnt,inMagic,inLot,inMaxThree,OpenThree); // consideramos la discrepancia e inmediatamente abrimos         
     }
   fnCalcPL(MxThree,inProfit,glFileLog);         // considerar el beneficio de los triángulos abiertos
   //fnCloseCheck(MxThree,glFileLog);           // comprobar si se cerraron con éxito
   fnCmnt(MxThree,OpenThree);                         // mostrar comentarios en la pantalla

   //abra el triángulo si de repente no se abrió
   for(int i=ArraySize(MxThree)-1;i>=0;i--)
     {
      if(MxThree[i].status==1)
        {
         if(MxThree[i].smb1.tkt<=0)
           {
            if(MxThree[i].smb1.side==1)   MxThree[i].smb1.tkt=OrderSend(MxThree[i].smb1.name,OP_BUY,MxThree[i].smb1.lot,NormalizeDouble(SymbolInfoDouble(MxThree[i].smb1.name,SYMBOL_ASK),(int)SymbolInfoInteger(MxThree[i].smb1.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxThree[i].cmnt,MxThree[i].magic,0,clrBlue);
            if(MxThree[i].smb1.side==-1)  MxThree[i].smb1.tkt=OrderSend(MxThree[i].smb1.name,OP_SELL,MxThree[i].smb1.lot,NormalizeDouble(SymbolInfoDouble(MxThree[i].smb1.name,SYMBOL_BID),(int)SymbolInfoInteger(MxThree[i].smb1.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxThree[i].cmnt,MxThree[i].magic,0,clrBlue);
           }
         if(MxThree[i].smb2.tkt<=0)
           {
            if(MxThree[i].smb2.side==1)   MxThree[i].smb2.tkt=OrderSend(MxThree[i].smb2.name,OP_BUY,MxThree[i].smb2.lot,NormalizeDouble(SymbolInfoDouble(MxThree[i].smb2.name,SYMBOL_ASK),(int)SymbolInfoInteger(MxThree[i].smb2.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxThree[i].cmnt,MxThree[i].magic,0,clrBlue);
            if(MxThree[i].smb2.side==-1)  MxThree[i].smb2.tkt=OrderSend(MxThree[i].smb2.name,OP_SELL,MxThree[i].smb2.lot,NormalizeDouble(SymbolInfoDouble(MxThree[i].smb2.name,SYMBOL_BID),(int)SymbolInfoInteger(MxThree[i].smb2.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxThree[i].cmnt,MxThree[i].magic,0,clrBlue);
           }
         if(MxThree[i].smb3.tkt<=0)
           {
            if(MxThree[i].smb3.side==1)   MxThree[i].smb3.tkt=OrderSend(MxThree[i].smb3.name,OP_BUY,MxThree[i].smb3.lot,NormalizeDouble(SymbolInfoDouble(MxThree[i].smb3.name,SYMBOL_ASK),(int)SymbolInfoInteger(MxThree[i].smb3.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxThree[i].cmnt,MxThree[i].magic,0,clrBlue);
            if(MxThree[i].smb3.side==-1)  MxThree[i].smb3.tkt=OrderSend(MxThree[i].smb3.name,OP_SELL,MxThree[i].smb3.lot,NormalizeDouble(SymbolInfoDouble(MxThree[i].smb3.name,SYMBOL_BID),(int)SymbolInfoInteger(MxThree[i].smb3.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxThree[i].cmnt,MxThree[i].magic,0,clrBlue);
           }

         if(MxThree[i].smb1.tkt>0 && MxThree[i].smb2.tkt>0 && MxThree[i].smb3.tkt>0) MxThree[i].status=2;
         else
         if(TimeCurrent()-MxThree[i].timeopen>MAXTIMEWAIT)
            MxThree[i].status=3;
         else continue;
        }
      if(MxThree[i].status==3) fnCloseThree(MxThree,i,glFileLog);
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   OnTick();
  }   
//+------------------------------------------------------------------+

class CSupport
  {
private:

public:
                     CSupport();
                    ~CSupport();

   uchar             NumberCount(double numer);    //Devuelve el número de decimales en decimal
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSupport::CSupport()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSupport::~CSupport()
  {
  }
//+------------------------------------------------------------------+
uchar CSupport::NumberCount(double numer)
  {
   uchar i=0;
   numer=MathAbs(numer);
   for(i=0;i<=8;i++) if(MathAbs(NormalizeDouble(numer,i)-numer)<=DBL_EPSILON) break;
   return(i);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

// estructura para un par de divisas
struct stSmb
  {
   string            name;            // Par de divisas
   int               digits;          // Número de decimales en la cita
   uchar             digits_lot;      // El número de decimales en el lote, para redondear
   int               Rpoint;          // 1 / punto multiplica los puntos en las fórmulas por este valor en lugar de dividir
   double            dev;             // posible deslizamiento. traducir inmediatamente a la cantidad de puntos
   double            lot;             // Volumen de negociación para 1 y 2 pares de divisas
   double            lotbuy;          // Volumen de negociación para la compra de un tercer par de divisas.
   double            lotsell;         // Volumen de negociación para la venta de un tercer par de divisas.
   double            lot_min;         // volumen mínimo
   double            lot_max;         // volumen máximo
   double            lot_step;        // mucho paso
   double            contract;        // tamaño del contrato
   double            price;           // El precio de apertura del par en el triángulo. necesario para la compensación
   int               tkt;            // ticket de pedido con el que se abre la transacción. solo se necesita por conveniencia en cuentas de cobertura
   MqlTick           tick;            // precios de par actuales
   double            tv;              //valor actual de la marca
   double            mrg;             // margen requerido actual para la apertura
   double            sppoint;         // difundir en puntos enteros
   double            spcost;          // diferencial de dinero en el lote abierto actual
   double            spcostbuy;       // diferencial de dinero en el lote abierto actual para el par 3
   double            spcostsell;      // diferencial de dinero en el lote abierto actual para el par 3
   string            base;
   string            prft;
   char              side;             //dirección en el triángulo. 0 = nichgeo. +1 compra -1 venta
                     stSmb(){price=0;tkt=0;mrg=0;side=0;}
  };
// estructura para triangulo
struct stThree
  {
   stSmb             smb1;
   stSmb             smb2;
   stSmb             smb3;
   int               magic;            // mago triángulo
   string            cmnt;
   uchar             status;           // estado del triángulo 0-no utilizado 1 - enviado a la apertura. 2: abierto con éxito. 3- enviado a cerrar
   double            pl;               // ganancia triangular
   datetime          timeopen;         // tiempo de apertura de un triángulo
   double            PLBuy;            // ¿Cuánto puedes ganar si compras un triángulo?
   double            PLSell;           // ¿Cuánto puedes ganar si vendes un triángulo?
   double            spreadbuy;           // Costo total de los tres diferenciales. con comisión
   double            spreadsell;           // Costo total de los tres diferenciales. con comisión
   double            aiScore;            // Score adaptativo IA [-1..1]
   uint              aiTrades;           // Total de operaciones cerradas
   uint              aiWins;             // Cierres positivos
   uint              aiLosses;           // Cierres negativos
   double            aiConfidence;       // Confianza actual de señal [0..100]
   double            lastPL;             // Último resultado cerrado
   double            nnProb;             // Probabilidad de red neuronal [0..1]
   double            mmBias;             // Sesgo market maker (-1 sell, +1 buy)
                     stThree(){status=0;magic=0;timeopen=0;aiScore=0;aiTrades=0;aiWins=0;aiLosses=0;aiConfidence=0;lastPL=0;nnProb=0.5;mmBias=0;}
  };

double fnClamp(double val,double mn,double mx);
void fnUpdateAIScore(stThree &MxSmb[],int idx);
void fnDeletePanel();
void fnDrawRightPanel(stThree &MxSmb[],ushort lcOpenThree);
int fnTFMinutes(ENUM_TIMEFRAMES tf);
double fnSigmoid(double x);
double fnEMAFromClose(string smb,ENUM_TIMEFRAMES tf,int period,int shift);
double fnRSIFromClose(string smb,ENUM_TIMEFRAMES tf,int period,int shift);
double fnCalcTDI(string smb,ENUM_TIMEFRAMES tf,int shift);
bool fnBuildNNFeatures(string smb,ENUM_TIMEFRAMES tf,int shift,double spreadPts,double &x1,double &x2,double &x3,double &x4,double &x5);
bool fnTrainNN90Days(stThree &MxSmb[]);
double fnPredictNN(string smb,double spreadPts);

stThree  MxThree[];
CSupport csup;

double fnClamp(double val,double mn,double mx)
  {
   if(val<mn) return(mn);
   if(val>mx) return(mx);
   return(val);
  }

void fnUpdateAIScore(stThree &MxSmb[],int idx)
  {
   if(idx<0 || idx>=ArraySize(MxSmb)) return;
   MxSmb[idx].aiTrades++;
   MxSmb[idx].lastPL=MxSmb[idx].pl;

   double outcome=-1.0;
   if(MxSmb[idx].pl>inProfit && MxSmb[idx].pl>0)
     {
      outcome=1.0;
      MxSmb[idx].aiWins++;
     }
   else MxSmb[idx].aiLosses++;

   MxSmb[idx].aiScore=0.85*MxSmb[idx].aiScore+0.15*outcome;
   MxSmb[idx].aiScore=fnClamp(MxSmb[idx].aiScore,-1.0,1.0);
  }

void fnDeletePanel()
  {
   ObjectDelete(0,glPanelBgName);
   ObjectDelete(0,glPanelTextName);
  }

int fnTFMinutes(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1: return 1;
      case PERIOD_M5: return 5;
      case PERIOD_M15: return 15;
      case PERIOD_M30: return 30;
      case PERIOD_H1: return 60;
      case PERIOD_H4: return 240;
      case PERIOD_D1: return 1440;
      default: return 15;
     }
  }

double fnSigmoid(double x)
  {
   if(x>35.0) return(1.0);
   if(x<-35.0) return(0.0);
   return(1.0/(1.0+MathExp(-x)));
  }

double fnEMAFromClose(string smb,ENUM_TIMEFRAMES tf,int period,int shift)
  {
   if(period<=1) return(iClose(smb,tf,shift));
   int warmup=period*4;
   int startShift=shift+warmup;
   double ema=iClose(smb,tf,startShift);
   if(ema<=0) return(0.0);
   double alpha=2.0/(period+1.0);
   for(int sh=startShift-1;sh>=shift;sh--)
     {
      double c=iClose(smb,tf,sh);
      if(c<=0) return(0.0);
      ema=alpha*c+(1.0-alpha)*ema;
     }
   return(ema);
  }

double fnRSIFromClose(string smb,ENUM_TIMEFRAMES tf,int period,int shift)
  {
   double gain=0.0,loss=0.0;
   for(int k=shift+period;k>shift;k--)
     {
      double c1=iClose(smb,tf,k-1);
      double c0=iClose(smb,tf,k);
      if(c1<=0 || c0<=0) return(50.0);
      double d=c1-c0;
      if(d>=0) gain+=d; else loss-=d;
     }
   if(loss<=0.0) return(100.0);
   double rs=(gain/period)/(loss/period);
   return(100.0-(100.0/(1.0+rs)));
  }

double fnCalcTDI(string smb,ENUM_TIMEFRAMES tf,int shift)
  {
   double rsi=fnRSIFromClose(smb,tf,13,shift);
   double sum=0.0;
   int n=0;
   for(int k=shift;k<shift+7;k++)
     {
      sum+=fnRSIFromClose(smb,tf,13,k);
      n++;
     }
   if(n<=0) return(0.0);
   double signal=sum/n;
   return((rsi-signal)/20.0);
  }

bool fnBuildNNFeatures(string smb,ENUM_TIMEFRAMES tf,int shift,double spreadPts,double &x1,double &x2,double &x3,double &x4,double &x5)
  {
   double p=SymbolInfoDouble(smb,SYMBOL_POINT);
   if(p<=0) p=0.0001;

   double ema50=fnEMAFromClose(smb,tf,50,shift);
   double ema200=fnEMAFromClose(smb,tf,200,shift);
   double ema50prev=fnEMAFromClose(smb,tf,50,shift+5);
   double rsi=fnRSIFromClose(smb,tf,13,shift);
   if(ema50<=0 || ema200<=0 || ema50prev<=0) return(false);

   x1=fnClamp((ema50-ema200)/(50.0*p),-3.0,3.0);
   x2=fnClamp((ema50-ema50prev)/(10.0*p),-3.0,3.0);
   x3=fnClamp((rsi-50.0)/25.0,-2.0,2.0);
   x4=fnClamp(fnCalcTDI(smb,tf,shift),-2.0,2.0);
   x5=fnClamp(spreadPts/50.0,0.0,2.0);
   return(true);
  }

bool fnTrainNN90Days(stThree &MxSmb[])
  {
   if(ArraySize(MxSmb)<=0) return(false);
   string smb=MxSmb[0].smb1.name;
   if(smb=="" || !fnSmbCheck(smb)) return(false);

   int tfMin=fnTFMinutes(inNNTimeframe);
   int needBars=(inNNTrainingDays*1440)/MathMax(tfMin,1)+260;
   int bars=iBars(smb,inNNTimeframe);
   int maxShift=MathMin(bars-3,needBars);
   if(maxShift<260) return(false);

   for(int e=0;e<inNNEpochs;e++)
     {
      for(int sh=maxShift;sh>=2;sh--)
        {
         double x1,x2,x3,x4,x5;
         double spreadPts=(double)SymbolInfoInteger(smb,SYMBOL_SPREAD);
         if(!fnBuildNNFeatures(smb,inNNTimeframe,sh,spreadPts,x1,x2,x3,x4,x5)) continue;

         double c0=iClose(smb,inNNTimeframe,sh);
         double c1=iClose(smb,inNNTimeframe,sh-1);
         if(c0==0 || c1==0) continue;

         double y=(c1>c0)?1.0:0.0;
         double z=glNNWeights[0]+glNNWeights[1]*x1+glNNWeights[2]*x2+glNNWeights[3]*x3+glNNWeights[4]*x4+glNNWeights[5]*x5;
         double pred=fnSigmoid(z);
         double err=(y-pred);

         glNNWeights[0]+=inNNLearningRate*err;
         glNNWeights[1]+=inNNLearningRate*err*x1;
         glNNWeights[2]+=inNNLearningRate*err*x2;
         glNNWeights[3]+=inNNLearningRate*err*x3;
         glNNWeights[4]+=inNNLearningRate*err*x4;
         glNNWeights[5]+=inNNLearningRate*err*x5;
        }
     }

   glNNReady=true;
   glNNLastTrain=TimeCurrent();
   Print("NN entrenada con "+(string)inNNTrainingDays+" dias en "+smb+" TF "+EnumToString(inNNTimeframe));
   return(true);
  }

double fnPredictNN(string smb,double spreadPts)
  {
   double x1,x2,x3,x4,x5;
   if(!glNNReady) return(0.5);
   if(!fnBuildNNFeatures(smb,inNNTimeframe,0,spreadPts,x1,x2,x3,x4,x5)) return(0.5);
   double z=glNNWeights[0]+glNNWeights[1]*x1+glNNWeights[2]*x2+glNNWeights[3]*x3+glNNWeights[4]*x4+glNNWeights[5]*x5;
   return(fnSigmoid(z));
  }

void fnDrawRightPanel(stThree &MxSmb[],ushort lcOpenThree)
  {
   string txt=" ARBITRAJE TRIANGULAR PRO\n";
   txt+="==========================\n";
   txt+="Triangulos: "+(string)ArraySize(MxSmb)+"\n";
   txt+="Abiertos: "+(string)lcOpenThree+"\n";

   double bestEdge=-DBL_MAX;
   int bestIdx=-1;
   double openPL=0;
   double avgScore=0;
   uint totalTrades=0,totalWins=0,totalLosses=0;

   for(int i=ArraySize(MxSmb)-1;i>=0;i--)
     {
      double edge=MathMax(MxSmb[i].PLBuy-MxSmb[i].spreadbuy,MxSmb[i].PLSell-MxSmb[i].spreadsell);
      if(edge>bestEdge)
        {
         bestEdge=edge;
         bestIdx=i;
        }
      if(MxSmb[i].status==2) openPL+=MxSmb[i].pl;
      avgScore+=MxSmb[i].aiScore;
      totalTrades+=MxSmb[i].aiTrades;
      totalWins+=MxSmb[i].aiWins;
      totalLosses+=MxSmb[i].aiLosses;
     }

   if(ArraySize(MxSmb)>0) avgScore/=ArraySize(MxSmb);

   txt+="P/L abierto: "+DoubleToString(openPL,2)+"\n";
   txt+="Score IA prom: "+DoubleToString(avgScore,3)+"\n";
   txt+="Trades IA: "+(string)totalTrades+" (W:"+(string)totalWins+" L:"+(string)totalLosses+")\n";
   txt+="NN: "+(inUseNeuralNet?"ON":"OFF")+"  TF:"+EnumToString(inNNTimeframe)+"\n";
   txt+="Ult. entrenamiento: "+(glNNLastTrain>0?TimeToString(glNNLastTrain,TIME_DATE|TIME_MINUTES):"N/A")+"\n";

   if(bestIdx>=0)
     {
      txt+="--------------------------\n";
      txt+="Mejor oportunidad:\n";
      txt+=MxSmb[bestIdx].smb1.name+"+"+MxSmb[bestIdx].smb2.name+"+"+MxSmb[bestIdx].smb3.name+"\n";
      txt+="PLBuy: "+DoubleToString(MxSmb[bestIdx].PLBuy,2)+" / Coste: "+DoubleToString(MxSmb[bestIdx].spreadbuy,2)+"\n";
      txt+="PLSell: "+DoubleToString(MxSmb[bestIdx].PLSell,2)+" / Coste: "+DoubleToString(MxSmb[bestIdx].spreadsell,2)+"\n";
      txt+="Confianza IA: "+DoubleToString(MxSmb[bestIdx].aiConfidence,1)+"%\n";
      txt+="NN Prob: "+DoubleToString(MxSmb[bestIdx].nnProb*100.0,1)+"%  MM:"+DoubleToString(MxSmb[bestIdx].mmBias,0)+"\n";
     }

   if(ObjectFind(0,glPanelBgName)<0) ObjectCreate(0,glPanelBgName,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_XSIZE,350);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_YSIZE,250);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_BGCOLOR,background_color);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,glPanelBgName,OBJPROP_BACK,false);

   if(ObjectFind(0,glPanelTextName)<0) ObjectCreate(0,glPanelTextName,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,glPanelTextName,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,glPanelTextName,OBJPROP_XDISTANCE,20);
   ObjectSetInteger(0,glPanelTextName,OBJPROP_YDISTANCE,30);
   ObjectSetInteger(0,glPanelTextName,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,glPanelTextName,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,glPanelTextName,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,glPanelTextName,OBJPROP_TEXT,txt);
  }

void fnWarning(double lot,int &fh)
  {
// Verifique la corrección de establecer el volumen de comercio, no podemos comerciar en volumen negativo
   if(lot<=0)
     {
      Alert("Trade volume <= 0");
      ExpertRemove();
     }

// Dado que el robot está escrito en un estilo de procedimiento, deberá crear varias variables globales
// uno de ellos es el archivo de registro de identificador. El nombre consta de una parte fija y la fecha de inicio del robot; todo esto para simplificar
// control, para no buscar en el mismo archivo donde comienza el registro para este o aquel robot.
// Vale la pena prestar atención a que el nombre no cambia durante un período determinado, pero cada vez con un nuevo comienzo
// en este caso, el archivo anterior, si lo hay, se elimina.

// En su trabajo, el experto utiliza 2 archivos: el primero es el archivo con los triángulos encontrados, se crea solo cuando
// la elección apropiada del usuario y el segundo es el archivo de registro donde se escriben los horarios de apertura y cierre del triángulo
// precios de apertura y alguna información adicional para un control más conveniente
// el archivo de registro siempre se mantiene           

// creamos un archivo de registro solo si el modo de creación de archivos de triángulos no está seleccionado, porque en este caso no es relevante                                 
   if(inMode!=CREATE_FILE)
     {
      string name=FILELOG+TimeToString(TimeCurrent(),TIME_DATE)+".csv";
      FileDelete(name);
      fh=FILEOPENWRITE(name);
      if(fh==INVALID_HANDLE) Alert("The log file is not created");
     }

// abrumadoramente, el tamaño del contrato para pares de divisas con corredores = 100,000, pero a veces hay excepciones
// son tan raros que es más fácil verificar este valor una vez al inicio, si no es igual a 100000, luego informarlo,
// para que el propio usuario decida si es importante o no y continúe trabajando más, sin describir más momentos cuando 
// los pares con diferentes tamaños de contrato se encuentran en un triángulo
   //string SymbolsArray[] = {"GBPUSD", "USDCHF", "USDJPY", "EURJPY", "GOLD"};
   //for(int i = ArraySize(SymbolsArray)-1; i >= 0; i--)
   for(int i=SymbolsTotal(true)-1;i>=0;i--)
     {
      string name=SymbolName(i,true);
     
      // La función de verificar el símbolo para la disponibilidad del comercio también se utiliza en la preparación de triángulos.
      // allí y considéralo con más detalle
      if(!fnSmbCheck(name)) continue;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnSetThree(stThree &MxSmb[],enMode mode)//CAMBIADO  JP
  {
// volcar nuestra matriz de triángulos
   ArrayFree(MxSmb);

// si no estamos en el probador, miramos qué modo de operación eligió el usuario
// Tomar personajes de una revisión de mercado o de un archivo
   if(mode==STANDART_MODE || mode==CREATE_FILE) fnGetThreeFromMarketWatch(MxSmb);
   if(mode==USE_FILE) fnGetThreeFromFile(MxSmb);
  }
//+------------------------------------------------------------------+

//tiene triángulos de archivo
void fnGetThreeFromFile(stThree &MxSmb[])
  {
// si no se encuentra el archivo de símbolos, imprima sobre él y salga
   int fh=FILEOPENREAD(FILENAME);
   if(fh==INVALID_HANDLE)
     {
      Print("Archivo con símbolos no leídos!");
      ExpertRemove();
     }

// mover el carro al comienzo del archivo
   FileSeek(fh,0,SEEK_SET);

// omita el encabezado, es decir primera línea de archivo     
   while(!FileIsLineEnding(fh)) FileReadString(fh);

   while(!FileIsEnding(fh) && !IsStopped())
     {
      // obtenemos tres símbolos triangulares. Hagamos una verificación básica de disponibilidad de datos y listo.
      // ya que el robot puede componer un archivo con triángulos automáticamente y si el usuario de repente
      // lo cambió de forma independiente y no es correcto que creamos que lo hizo conscientemente
      string smb1=FileReadString(fh);
      string smb2=FileReadString(fh);
      string smb3=FileReadString(fh);

      // Si hay datos de caracteres disponibles, luego, al final de la línea, escríbalos en nuestra matriz de triángulos
      if(!fnSmbCheck(smb1) || !fnSmbCheck(smb2) || !fnSmbCheck(smb3)) {while(!FileIsLineEnding(fh)) FileReadString(fh);continue;}

      int cnt=ArraySize(MxSmb);
      ArrayResize(MxSmb,cnt+1);
      MxSmb[cnt].smb1.name=smb1;
      MxSmb[cnt].smb2.name=smb2;
      MxSmb[cnt].smb3.name=smb3;

      string base,prft;

      fnGetBaseProfit(MxSmb[cnt].smb1.name,base,prft);
      MxSmb[cnt].smb1.base=base;
      MxSmb[cnt].smb1.prft=prft;

      fnGetBaseProfit(MxSmb[cnt].smb2.name,base,prft);
      MxSmb[cnt].smb2.base=base;
      MxSmb[cnt].smb2.prft=prft;

      fnGetBaseProfit(MxSmb[cnt].smb3.name,base,prft);
      MxSmb[cnt].smb3.base=base;
      MxSmb[cnt].smb3.prft=prft;

      while(!FileIsLineEnding(fh)) FileReadString(fh);
     }
  }
//obtuve triángulos de una revisión de mercado

void fnGetThreeFromMarketWatch(stThree &MxSmb[])
  {
// obtenemos el número total de caracteres
   int total=SymbolsTotal(true);

// variables para comparar el tamaño del contrato              

// en el primer ciclo tomamos el primer personaje de la lista
   for(int i=0;i<total-2 && !IsStopped();i++)
     {//1
      string sm1=SymbolName(i,true);

      // revisa el personaje por varias restricciones
      if(!fnSmbCheck(sm1)) continue;

      // obtenemos la moneda base y la moneda de ganancias desde la comparación se lleva a cabo precisamente en ellos, y no en el nombre de la pareja
      // por lo tanto, varios prefijos y sufijos inventados por el corredor no importan
      string sm1base="",sm1prft="";
      if(!fnGetBaseProfit(sm1,sm1base,sm1prft)) continue;

      // en el segundo ciclo tomamos el siguiente personaje de la lista
      for(int j=i+1;j<total-1 && !IsStopped();j++)
        {//2
         string sm2=SymbolName(j,true);
         if(!fnSmbCheck(sm2)) continue;
         string sm2base="",sm2prft="";
         if(!fnGetBaseProfit(sm2,sm2base,sm2prft)) continue;
         // el primer y el segundo par deben tener una coincidencia de cualquiera de las monedas
         // si no está allí, entonces no podemos hacer un triángulo de ninguna manera    
         // al mismo tiempo, no tiene sentido llevar a cabo una verificación de identidad completa, porque si son, por ejemplo,
         // eurusd y eurusd.xxx el triángulo de todos ellos no se hará
         if(sm1base==sm2base || sm1base==sm2prft || sm1prft==sm2base || sm1prft==sm2prft); else continue;

         // en el tercer ciclo buscamos el último símbolo para el triángulo
         for(int k=j+1;k<total && !IsStopped();k++)
           {//3
            string sm3=SymbolName(k,true);
            if(!fnSmbCheck(sm3)) continue;

            string sm3base="",sm3prft="";
            if(!fnGetBaseProfit(sm3,sm3base,sm3prft)) continue;

            // Sabemos que el primer y el segundo símbolo tienen una moneda común. Para hacer un triángulo necesitas encontrar tal
            // un tercer par de divisas, una de las cuales coincide con cualquier moneda del primer par, y la otra con
            // cualquier moneda del segundo, si no hay coincidencia, entonces este par no encaja
            if(sm3base==sm1base || sm3base==sm1prft || sm3base==sm2base || sm3base==sm2prft);else continue;
            if(sm3prft==sm1base || sm3prft==sm1prft || sm3prft==sm2base || sm3prft==sm2prft);else continue;

            //verificación de identidad completa
            if(sm1base==sm2base && sm1prft==sm2prft) continue;
            if(sm1base==sm3base && sm1prft==sm3prft) continue;
            if(sm2base==sm3base && sm2prft==sm3prft) continue;

            // si llegas aquí, se pasan todos los controles y puedes hacer un triángulo a partir de estos tres pares encontrados
            // escríbelo a nuestra matriz
            int cnt=ArraySize(MxSmb);
            ArrayResize(MxSmb,cnt+1);
            MxSmb[cnt].smb1.name=sm1;
            MxSmb[cnt].smb2.name=sm2;
            MxSmb[cnt].smb3.name=sm3;

            MxSmb[cnt].smb1.base=sm1base;
            MxSmb[cnt].smb1.prft=sm1prft;

            MxSmb[cnt].smb2.base=sm2base;
            MxSmb[cnt].smb2.prft=sm2prft;

            MxSmb[cnt].smb3.base=sm3base;
            MxSmb[cnt].smb3.prft=sm3prft;
            break;
           }//3
        }//2
     }//1    
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool fnGetBaseProfit(string smb,string &base,string &prft)
  {
   if(!SymbolInfoString(smb,SYMBOL_CURRENCY_BASE,base)) return(false);
   if(!SymbolInfoString(smb,SYMBOL_CURRENCY_PROFIT,prft)) return(false);

   if(SymbolInfoInteger(smb,SYMBOL_TRADE_CALC_MODE)==0) return(true);

   if(StringLen(smb)<6) return(false);
   if(StringLen(prft)!=3) return(false);
   if (base!=prft) return(false);
   if (StringFind(smb,base,0)<0) return(false);
   if(StringFind(smb,prft,0)<3) return(false);

   base=StringSubstr(smb,0,3);
   if(base=="") return(false);

   return(true);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool fnSmbCheck(string smb)
  {
   if(smb=="") return(false);

// Si hay restricciones en el comercio, omita este símbolo
   if(SymbolInfoInteger(smb,SYMBOL_TRADE_MODE)!=SYMBOL_TRADE_MODE_FULL) return(false);

// si hay una fecha de inicio y finalización para el contrato, omita también, para las monedas, este parámetro no se usa
// necesita porque Algunos corredores de instrumentos urgentes indican el método de cálculo de divisas. así que los eliminaremos
   if(SymbolInfoInteger(smb,SYMBOL_START_TIME)!=0)return(false);
   if(SymbolInfoInteger(smb,SYMBOL_EXPIRATION_TIME)!=0) return(false);

   if(!SymbolInfoInteger(smb,SYMBOL_SELECT)) return(false);

// La verificación a continuación solo es necesaria en el trabajo real, porque a veces por alguna razón sucedemos que SymbolInfoTick funciona y los precios de alguna manera
// recibido de hecho preguntar o pujar = 0.

   MqlTick tk;
   if(!SymbolInfoTick(smb,tk)) return(false);

   return(true);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnChangeThree(stThree &MxSmb[])
  {
   for(int i=ArraySize(MxSmb)-1;i>=0;i--)
     {//for         
      // primero decide qué está en tercer lugar
      // en tercer lugar está el par cuya moneda base no coincide con otras dos monedas base

      // si los caracteres de la moneda base 1 y 2 coinciden, omita este paso, si no, intercambie los pares
      if(MxSmb[i].smb1.base!=MxSmb[i].smb2.base)
        {
         if(MxSmb[i].smb1.base==MxSmb[i].smb3.base)
           {
            string temp=MxSmb[i].smb2.name;
            MxSmb[i].smb2.name=MxSmb[i].smb3.name;
            MxSmb[i].smb3.name=temp;

            string base,prft;

            fnGetBaseProfit(MxSmb[i].smb2.name,base,prft);
            MxSmb[i].smb2.base=base;
            MxSmb[i].smb2.prft=prft;
            fnGetBaseProfit(MxSmb[i].smb3.name,base,prft);
            MxSmb[i].smb3.base=base;
            MxSmb[i].smb3.prft=prft;
           }

         if(MxSmb[i].smb2.base==MxSmb[i].smb3.base)
           {
            string temp=MxSmb[i].smb1.name;
            MxSmb[i].smb1.name=MxSmb[i].smb3.name;
            MxSmb[i].smb3.name=temp;

            string base,prft;

            fnGetBaseProfit(MxSmb[i].smb1.name,base,prft);
            MxSmb[i].smb1.base=base;
            MxSmb[i].smb1.prft=prft;
            fnGetBaseProfit(MxSmb[i].smb3.name,base,prft);
            MxSmb[i].smb3.base=base;
            MxSmb[i].smb3.prft=prft;
           }
        }

      //ahora defina el primer y segundo lugar
      //en segundo lugar está el par cuya moneda de beneficio coincide con la moneda base del tercero.
      //en este caso siempre usamos multiplicación

      // intercambia el primer y el segundo par
      if(MxSmb[i].smb3.base!=MxSmb[i].smb2.prft)
        {
         string temp=MxSmb[i].smb1.name;
         MxSmb[i].smb1.name=MxSmb[i].smb2.name;
         MxSmb[i].smb2.name=temp;

         string base,prft;

         fnGetBaseProfit(MxSmb[i].smb1.name,base,prft);
         MxSmb[i].smb1.base=base;
         MxSmb[i].smb1.prft=prft;
         fnGetBaseProfit(MxSmb[i].smb2.name,base,prft);
         MxSmb[i].smb2.base=base;
         MxSmb[i].smb2.prft=prft;
        }
     }//for
  }
//+------------------------------------------------------------------+
//Cargamos varios datos en símbolos como el número de caracteres en una cotización, lote, etc.

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnSmbLoad(double lot,stThree &MxSmb[])
  {
// macro simple para imprimir   
#define prnt(nm) {nm="";Print("NOT CORRECT LOAD: "+nm);continue;}

//recorre todos los triángulos ensamblados. Aquí tendremos excesos de tiempo para solicitudes de datos repetidas para uno y 
// los mismos símbolos, pero dado que hacemos esta operación solo una vez, al cargar el robot, podemos hacerlo por la reducción del código.
// Utilizamos la biblioteca estándar para obtener los datos. No hay necesidad urgente de usarlo, pero que sea una fuerza de hábito
   for(int i=ArraySize(MxSmb)-1;i>=0;i--)
     {
      // cargando el símbolo en la clase CSymbolInfo, inicializamos la recopilación de todos los datos que necesitamos
      // y, al mismo tiempo, verificamos su disponibilidad, si algo está mal, marque el triángulo con un código que no funcione
      if(!fnSmbCheck(MxSmb[i].smb1.name)) prnt(MxSmb[i].smb1.name);
      // tengo _Dígitos para cada personaje
      MxSmb[i].smb1.digits=(int)SymbolInfoInteger(MxSmb[i].smb1.name,SYMBOL_DIGITS);

      //Traducimos el deslizamiento de puntos enteros a decimales. Necesitaremos dicho formato más para los cálculos.
      MxSmb[i].smb1.dev=DEVIATION*SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_TRADE_TICK_SIZE);

      // Para traducir las cotizaciones a la cantidad de puntos, a menudo tenemos que dividir el precio por el valor de _Point
      // es mejor representar este valor en la forma 1 / Punto y luego reemplazaremos la división por multiplicación
      // no hay verificación csmb.Point () para 0, porque en primer lugar, no puede ser igual a 0, y si ocurre un milagro
      // y el parámetro no se recibe, entonces este triángulo será eliminado por la línea if (!csmb.Name(MxSmb[i].smb1.name))	         

      double pnt=SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_TRADE_TICK_SIZE);
      if(pnt>0) MxSmb[i].smb1.Rpoint=int(NormalizeDouble(1/pnt,0));

      // a tantas señales rodeamos el lote. Se considera simple = el número de lugares decimales en la variable LotStep
      MxSmb[i].smb1.digits_lot=csup.NumberCount(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_VOLUME_STEP));

      // límites de volumen normalizados inmediatamente
      MxSmb[i].smb1.lot_min=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_VOLUME_MIN),MxSmb[i].smb1.digits_lot);
      MxSmb[i].smb1.lot_max=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_VOLUME_MAX),MxSmb[i].smb1.digits_lot);
      MxSmb[i].smb1.lot_step=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_VOLUME_STEP),MxSmb[i].smb1.digits_lot);

      //tamaño del contrato 
      MxSmb[i].smb1.contract=SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_TRADE_CONTRACT_SIZE);

      if(!fnSmbCheck(MxSmb[i].smb2.name)) prnt(MxSmb[i].smb2.name);
      MxSmb[i].smb2.digits=(int)SymbolInfoInteger(MxSmb[i].smb2.name,SYMBOL_DIGITS);
      MxSmb[i].smb2.dev=DEVIATION*SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_TRADE_TICK_SIZE);
      pnt=SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_TRADE_TICK_SIZE);
      if(pnt>0) MxSmb[i].smb2.Rpoint=int(NormalizeDouble(1/pnt,0));
      MxSmb[i].smb2.digits_lot=csup.NumberCount(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_VOLUME_STEP));
      MxSmb[i].smb2.lot_min=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_VOLUME_MIN),MxSmb[i].smb2.digits_lot);
      MxSmb[i].smb2.lot_max=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_VOLUME_MAX),MxSmb[i].smb2.digits_lot);
      MxSmb[i].smb2.lot_step=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_VOLUME_STEP),MxSmb[i].smb2.digits_lot);
      MxSmb[i].smb2.contract=SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_TRADE_CONTRACT_SIZE);

      if(!fnSmbCheck(MxSmb[i].smb3.name)) prnt(MxSmb[i].smb3.name);
      MxSmb[i].smb3.digits=(int)SymbolInfoInteger(MxSmb[i].smb3.name,SYMBOL_DIGITS);
      MxSmb[i].smb3.dev=DEVIATION*SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_TRADE_TICK_SIZE);
      pnt=SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_TRADE_TICK_SIZE);
      if(pnt>0) MxSmb[i].smb3.Rpoint=int(NormalizeDouble(1/pnt,0));
      MxSmb[i].smb3.digits_lot=csup.NumberCount(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_VOLUME_STEP));
      MxSmb[i].smb3.lot_min=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_VOLUME_MIN),MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lot_max=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_VOLUME_MAX),MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lot_step=NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_VOLUME_STEP),MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.contract=SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_TRADE_CONTRACT_SIZE);

      // alinear el volumen de comercio

      MxSmb[i].smb1.lot=NormalizeDouble(lot,MxSmb[i].smb1.digits_lot);
      MxSmb[i].smb2.lot=NormalizeDouble(MxSmb[i].smb1.lot*MxSmb[i].smb1.contract/MxSmb[i].smb2.contract,MxSmb[i].smb2.digits_lot);

      //calculamos el volumen para el tercer par si ingresamos ahora
      //solo es necesario comprender qué volúmenes mínimos deben establecerse         
      MxSmb[i].smb3.lotbuy=SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_ASK)*MxSmb[i].smb2.lot*MxSmb[i].smb2.contract/MxSmb[i].smb3.contract;
      MxSmb[i].smb3.lotsell=SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_BID)*MxSmb[i].smb2.lot*MxSmb[i].smb2.contract/MxSmb[i].smb3.contract;
      MxSmb[i].smb3.lotbuy=NormalizeDouble(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lotsell=NormalizeDouble(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);

      // Verificaciones de límite                          
      if(MxSmb[i].smb1.lot<MxSmb[i].smb1.lot_min)
        {
         string txt="Triangulos: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" - volumen mínimo no correcto.";
         txt=txt+" Volumen máximo recomendado de: "+MxSmb[i].smb1.name+"  "+DoubleToString(MxSmb[i].smb1.lot_min,MxSmb[i].smb1.digits_lot);
         txt=txt+" Calc volume: "+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);
         Alert(txt);
         continue;
        }
      if(MxSmb[i].smb2.lot<MxSmb[i].smb2.lot_min)
        {
         string txt="Triangulos: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" - volumen mínimo no correcto.";
         txt=txt+" Volumen máximo recomendado de: "+MxSmb[i].smb2.name+"  "+DoubleToString(MxSmb[i].smb2.lot_min,MxSmb[i].smb2.digits_lot);
         txt=txt+" Calc volume: "+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);
         Alert(txt);
         continue;
        }
      if(MxSmb[i].smb3.lotsell<MxSmb[i].smb3.lot_min || MxSmb[i].smb3.lotbuy<MxSmb[i].smb3.lot_min)
        {
         string txt="Triangulos: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" - volumen mínimo no correcto.";
         txt=txt+" Volumen máximo recomendado de: "+MxSmb[i].smb3.name+"  "+DoubleToString(MxSmb[i].smb3.lot_min,MxSmb[i].smb3.digits_lot);
         txt=txt+" Calc volume: "+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);
         Alert(txt);
         continue;
        }

      if(MxSmb[i].smb1.lot>MxSmb[i].smb1.lot_max)
        {
         string txt="Triangulos: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" - volumen máximo no correcto.";
         txt=txt+" Volumen máximo recomendado de: "+MxSmb[i].smb1.name+"  "+DoubleToString(MxSmb[i].smb1.lot_max,MxSmb[i].smb1.digits_lot);
         txt=txt+" Calc volume: "+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);
         Alert(txt);
         continue;
        }
      if(MxSmb[i].smb2.lot>MxSmb[i].smb2.lot_max)
        {
         string txt="Triangulos: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" - volumen máximo no correcto.";
         txt=txt+" Volumen máximo recomendado de: "+MxSmb[i].smb2.name+"  "+DoubleToString(MxSmb[i].smb2.lot_max,MxSmb[i].smb2.digits_lot);
         txt=txt+" Calc volume: "+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);
         Alert(txt);
         continue;
        }
      if(MxSmb[i].smb3.lotsell>MxSmb[i].smb3.lot_max || MxSmb[i].smb3.lotbuy>MxSmb[i].smb3.lot_max)
        {
         string txt="Triangulos: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" - volumen máximo no correcto.";
         txt=txt+" Volumen máximo recomendado de: "+MxSmb[i].smb3.name+"  "+DoubleToString(MxSmb[i].smb3.lot_max,MxSmb[i].smb3.digits_lot);
         txt=txt+" Calc volume: "+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot)+"  "
             +DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);
         Alert(txt);
         continue;
        }

      Print("Find Triangulos: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+
            " : Lot_1 "+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+
            " : Lot_2 "+DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot)+
            " : Lot_3_Buy "+DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot)+
            " : Lot_3_Sell "+DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot)
            );
     }
  }
//+------------------------------------------------------------------+
//consideramos todos los costos deslizantes y buscamos un triángulo para ingresar e inmediatamente abrir
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnCalcDelta(stThree &MxSmb[],double prft,string cmnt,int magic,double lot,ushort lcMaxThree,ushort &lcOpenThree)
  {
   double   temp=0;
   datetime tm=TimeCurrent();

   for(int i=ArraySize(MxSmb)-1;i>=0;i--)
     {//for i
      // si hay triángulos en el trabajo, entonces lo omitimos
      if(MxSmb[i].status!=0) continue;
      if(tm-MxSmb[i].timeopen<PAUSESECUND) continue;

      // nuevamente verificamos la disponibilidad de los tres pares, porque si al menos uno de ellos no está disponible
      // entonces no tiene sentido contar todo el triángulo
      if(!fnSmbCheck(MxSmb[i].smb1.name)) continue;
      if(!fnSmbCheck(MxSmb[i].smb2.name)) continue;  //de repente por algún par cerró la subasta
      if(!fnSmbCheck(MxSmb[i].smb3.name)) continue;

      // el número de triángulos abiertos se considera al comienzo de cada marca
      // pero también podemos abrirlos dentro de la marca, por lo que monitoreamos constantemente su número
      if(lcMaxThree>0) {if(lcMaxThree>lcOpenThree); else continue;}//se puede abrir todavía o no

                                                                   // entonces obtendremos todos los datos necesarios para los cálculos

      // obtuve el valor de tick para cada par de cálculos
      if(!SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_TRADE_TICK_VALUE,MxSmb[i].smb1.tv)) continue;
      if(!SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_TRADE_TICK_VALUE,MxSmb[i].smb2.tv)) continue;
      if(!SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_TRADE_TICK_VALUE,MxSmb[i].smb3.tv)) continue;

      // tiene precios actuales
      if(!SymbolInfoTick(MxSmb[i].smb1.name,MxSmb[i].smb1.tick)) continue;
      if(!SymbolInfoTick(MxSmb[i].smb2.name,MxSmb[i].smb2.tick)) continue;
      if(!SymbolInfoTick(MxSmb[i].smb3.name,MxSmb[i].smb3.tick)) continue;

      // Como dije anteriormente, por alguna razón, con una oferta exitosa, a veces sucede que ask o bid = 0
      // tener que pasar tiempo revisando precios
      if(MxSmb[i].smb1.tick.ask<=0 || MxSmb[i].smb1.tick.bid<=0 || MxSmb[i].smb2.tick.ask<=0 || MxSmb[i].smb2.tick.bid<=0 || MxSmb[i].smb3.tick.ask<=0 || MxSmb[i].smb3.tick.bid<=0) continue;

      //Si no ha recibido nuevos precios durante más de 2 minutos, no ingresamos el triángulo
      temp=(int)TimeCurrent();
      if(temp-MxSmb[i].smb1.tick.time>120) continue;
      if(temp-MxSmb[i].smb2.tick.time>120) continue;
      if(temp-MxSmb[i].smb3.tick.time>120) continue;

      // Calculamos el volumen para el tercer par. Sabemos el volumen para dos primeros pares, es igual y fijo.
      // El volumen del tercer par se cambia constantemente. Pero él se calcula sólo si el valor del lote no es 0 en las variables iniciales.
      // Si el lote es 0, va a  usarse el volumen mínimo igual.
      // La lógica del cálculo es simple. Recordamos nuestra versión del triángulo: EURUSD=EURGBP*GBPUSD. El número de libras compradas o vendidas
      // depende directamente de la cotización EURGBP, mientras que el tercer par esta divisa se encuentra en el primer lugar. Nos libramos de una parte de los cálculos
      // tomando como volumen el precio del segundo par. He cogido la media entre ask y bid
      // No olvidamos de la corrección respecto al volumen comercial de entrada.

      MxSmb[i].smb3.lotbuy=MxSmb[i].smb2.tick.ask*MxSmb[i].smb2.lot*MxSmb[i].smb2.contract/MxSmb[i].smb3.contract;
      MxSmb[i].smb3.lotsell=MxSmb[i].smb2.tick.bid*MxSmb[i].smb2.lot*MxSmb[i].smb2.contract/MxSmb[i].smb3.contract;

      if(MxSmb[i].smb2.prft=="USD")
        {
         MxSmb[i].smb3.lotbuy/=100;
         MxSmb[i].smb3.lotsell/=100;
        }
      MxSmb[i].smb3.lotbuy=NormalizeDouble(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lotsell=NormalizeDouble(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot);

      // Si el volumen calculado está fuera de los límites permitidos, aún no trabajamos con este triángulo
      if(MxSmb[i].smb3.lotbuy<MxSmb[i].smb3.lot_min || MxSmb[i].smb3.lotbuy>MxSmb[i].smb3.lot_max) continue;
      if(MxSmb[i].smb3.lotsell<MxSmb[i].smb3.lot_min || MxSmb[i].smb3.lotsell>MxSmb[i].smb3.lot_max) continue;
      if(lot<MxSmb[i].smb1.lot_min || lot>MxSmb[i].smb1.lot_max) continue;

      // consideramos nuestros costos, es decir spread + comisión. pr = propagación en puntos enteros
      // es la propagación lo que nos impide obtener esta estrategia, por lo que debe tenerse en cuenta
      // No puede usar la diferencia de precio multiplicada por el punto inverso, sino tomar el diferencial en puntos inmediatamente
      // SymbolInfoInteger(Symbol(),SYMBOL_SPREAD) - ahora es difícil decir por qué no elegí esta opción
      // puede deberse al hecho de que los precios ya se han recibido de mí y para no volver a recurrir al medio ambiente
      // puede haber realizado previamente pruebas más rápidas. No recuerdo, el robot fue escrito hace mucho tiempo.

      MxSmb[i].smb1.sppoint=NormalizeDouble(MxSmb[i].smb1.tick.ask-MxSmb[i].smb1.tick.bid,MxSmb[i].smb1.digits)*MxSmb[i].smb1.Rpoint;
      MxSmb[i].smb2.sppoint=NormalizeDouble(MxSmb[i].smb2.tick.ask-MxSmb[i].smb2.tick.bid,MxSmb[i].smb2.digits)*MxSmb[i].smb2.Rpoint;
      MxSmb[i].smb3.sppoint=NormalizeDouble(MxSmb[i].smb3.tick.ask-MxSmb[i].smb3.tick.bid,MxSmb[i].smb3.digits)*MxSmb[i].smb3.Rpoint;

      // Suena salvaje, pero sí, verificamos la propagación en busca de un valor negativo; esto es muy frecuente en el probador. En tiempo real, no encontré esto
      if(MxSmb[i].smb1.sppoint<=0 || MxSmb[i].smb2.sppoint<=0 || MxSmb[i].smb3.sppoint<=0) continue;

      // hay un diferencial en los juegos de palabras, ahora lo consideramos en dinero, o más bien en la moneda de depósito
      // en moneda, el valor de 1 tick siempre es igual al parámetro SYMBOL_TRADE_TICK_VALUE
      // tampoco te olvides de los volúmenes de negociación
      MxSmb[i].smb1.spcost=MxSmb[i].smb1.sppoint*MxSmb[i].smb1.tv*MxSmb[i].smb1.lot;
      MxSmb[i].smb2.spcost=MxSmb[i].smb2.sppoint*MxSmb[i].smb2.tv*MxSmb[i].smb2.lot;
      MxSmb[i].smb3.spcostbuy=MxSmb[i].smb3.sppoint*MxSmb[i].smb3.tv*MxSmb[i].smb3.lotbuy;
      MxSmb[i].smb3.spcostsell=MxSmb[i].smb3.sppoint*MxSmb[i].smb3.tv*MxSmb[i].smb3.lotsell;

      // así que aquí están nuestros costos para el volumen comercial especificado con una comisión adicional, que el usuario indica
      MxSmb[i].spreadbuy=MxSmb[i].smb1.spcost+MxSmb[i].smb2.spcost+MxSmb[i].smb3.spcostsell+prft;
      MxSmb[i].spreadsell=MxSmb[i].smb1.spcost+MxSmb[i].smb2.spcost+MxSmb[i].smb3.spcostbuy+prft;

      // Podemos monitorear la situación cuando el ask de la cartera < del bid, pero estas situaciones son muy raras, 
      // y se puede no considerarlas separadamente. Además, el arbitraje distribuido por el tiempo, también procesará esta situación.
      // Pues bien, la ubicación dentro de la posición está libre de riesgos, y por eso, por ejemplo hemos comprado eurusd,
      // y en seguida lo hemos vendido a través de eurgbp y gbpusd. 
      // Es decir, hemos visto que ask eurusd< bid eurgbp * bid gbpusd. Estas situaciones son frecuentes, pero para una entrada exitosa, eso no es suficiente.
      // Calcularemos además los gastos para el spread. Hay que entrar no sólo cuando ask < bid, sino cuando la diferencia entre
      // ellos supera los gastos para el spread.          
         
      // Vamos a acordar que la compra significa que hemos comprado el primer símbolo y hemos vendido otros dos,
      // y la venta es cuando hemos vendido el primer par y hemos comprado otros dos.

      temp=MxSmb[i].smb1.tv*MxSmb[i].smb1.Rpoint*MxSmb[i].smb1.lot;

      // Vamos a considerar en detalle la fórmula del cálculo. 
      // 1. Entre paréntesis, cada precio se corrige por el deslizamiento en el lado peor: MxSmb[i].smb2.tick.bid-MxSmb[i].smb2.dev
      // 2. Como se muestra en la fórmula de arriba, bid eurgbp * bid gbpusd - multiplicamos los precios del segundo y tercer símbolo:
      //    (MxSmb[i].smb2.tick.bid-MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.bid-MxSmb[i].smb3.dev)
      // 3. Luego, calculamos la diferencia entre ask y bid
      // 4. Hemos obtenido la diferencia en puntos la que ahora hay que pasar en dinero: multiplicar 
      // el coste del punto y volumen comercial. Para este propósito, cogemos los valores del primer par.
      // Si estuviéramos construyendo el triángulo, moviendo todos los pares al mismo lado y realizando la comparación con 1, 
      MxSmb[i].PLBuy=((MxSmb[i].smb2.tick.bid-MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.bid-MxSmb[i].smb3.dev)-(MxSmb[i].smb1.tick.ask+MxSmb[i].smb1.dev))*temp;
      MxSmb[i].PLSell=((MxSmb[i].smb1.tick.bid-MxSmb[i].smb1.dev)-(MxSmb[i].smb2.tick.ask+MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.ask+MxSmb[i].smb3.dev))*temp;

      // Tenemos dinero que podemos ganar o perder si compramos o vendemos triángulos.
      // Queda por comparar con los costos, si obtenemos más de lo que gastamos, puede ingresar
      // más de este enfoque: sabemos de inmediato cuánto podemos ganar aproximadamente
      // normalizar todo a 2 dígitos, porque ya es dinero
      MxSmb[i].PLBuy=NormalizeDouble(MxSmb[i].PLBuy,2);
      MxSmb[i].PLSell=NormalizeDouble(MxSmb[i].PLSell,2);
      MxSmb[i].spreadbuy=NormalizeDouble(MxSmb[i].spreadbuy,2);
      MxSmb[i].spreadsell=NormalizeDouble(MxSmb[i].spreadsell,2);

      // Métrica de edge y confianza para panel/filtro adaptativo IA
      double edgeBuy=MxSmb[i].PLBuy-MxSmb[i].spreadbuy;
      double edgeSell=MxSmb[i].PLSell-MxSmb[i].spreadsell;
      double bestEdge=MathMax(edgeBuy,edgeSell);
      double worstEdge=MathMin(edgeBuy,edgeSell);
      double den=MathAbs(bestEdge)+MathAbs(worstEdge)+0.00001;
      MxSmb[i].aiConfidence=fnClamp(((bestEdge-worstEdge)/den)*100.0,0.0,100.0);

      bool allowByIA=true;
      if(inUseIA)
        {
         double minScore=-0.25+inAIAgressividad*0.50;
         double minConf=20.0+inAIAgressividad*55.0;
         allowByIA=(MxSmb[i].aiScore>=minScore && MxSmb[i].aiConfidence>=minConf);
        }

      // Red neuronal + filtros técnicos EMA50/200 y TDI + sesgo Market Maker
      double spreadPts=(double)SymbolInfoInteger(MxSmb[i].smb1.name,SYMBOL_SPREAD);
      MxSmb[i].nnProb=fnPredictNN(MxSmb[i].smb1.name,spreadPts);
      double ema50Now=fnEMAFromClose(MxSmb[i].smb1.name,inNNTimeframe,50,0);
      double ema200Now=fnEMAFromClose(MxSmb[i].smb1.name,inNNTimeframe,200,0);
      double tdiNow=fnCalcTDI(MxSmb[i].smb1.name,inNNTimeframe,0);
      MxSmb[i].mmBias=0;
      if(ema50Now>ema200Now && tdiNow>0) MxSmb[i].mmBias=1;
      if(ema50Now<ema200Now && tdiNow<0) MxSmb[i].mmBias=-1;

      bool nnAllowBuy=(!inUseNeuralNet || (MxSmb[i].nnProb>=inNNBuyThreshold));
      bool nnAllowSell=(!inUseNeuralNet || (MxSmb[i].nnProb<=inNNSellThreshold));
      bool mmAllowBuy=(!inUseMMMethod || MxSmb[i].mmBias>=0);
      bool mmAllowSell=(!inUseMMMethod || MxSmb[i].mmBias<=0);

      // Si hay ganancias potenciales, entonces es necesario realizar más controles sobre la adecuación de los fondos para la apertura
      if((MxSmb[i].PLBuy>MxSmb[i].spreadbuy || MxSmb[i].PLSell>MxSmb[i].spreadsell) && allowByIA)
        {
         // No me molesté con la dirección de la transacción, solo calculé el margen total para la compra, todavía es más alto que para la venta
         // También vale la pena prestar atención al coeficiente creciente
         // No puede abrir el triángulo cuando el margen es suficiente. Factor creciente tomado, por defecto = 20%
         // aunque esta verificación, por extraño que parezca, a veces no funciona, todavía no entiendo por qué

         MxSmb[i].smb1.mrg=MarketInfo(MxSmb[i].smb1.name,MODE_MARGINREQUIRED)*MxSmb[i].smb1.lot;
         MxSmb[i].smb2.mrg=MarketInfo(MxSmb[i].smb2.name,MODE_MARGINREQUIRED)*MxSmb[i].smb2.lot;

         //Estamos casi a punto para la apertura, queda sólo encontrar un magic libre de nuestro diapasón. 
         // El magic inicial se indica en los parámetros de entrad, en la variable inMagic y por defecto es igual a 300. 
         // El diapasón de los magic se indica en la directiva define MAGIC, por defecto es 200.
         MxSmb[i].magic=fnMagicGet(MxSmb,magic);
         if(MxSmb[i].magic<=0)
           { // Si obtenemos 0, todos los magic están ocupados. Enviamos el mensaje de ello y salimos.
            Print("Free magic ended\nNew triangles will not open");
            break;
           }

         // Creamos el comentario para el triángulo
         MxSmb[i].cmnt=cmnt+(string)MxSmb[i].magic+" Open";

        // Nos abrimos, recordando de paso la hora del envío del triángulo para la apertura. 
        // Eso es necesario para no estar a la espera. 
        // Por defecto en la define MAXTIMEWAIT se pone el tiempo de espera hasta la apertura total en 3 segundos.
        // Si no nos hemos abierto durante este tiempo, enviamos lo que ha logrado abrirse para el cierre.

         if(MxSmb[i].PLBuy>MxSmb[i].spreadbuy && nnAllowBuy && mmAllowBuy)
           {
            MxSmb[i].smb3.mrg=MarketInfo(MxSmb[i].smb3.name,MODE_MARGINREQUIRED)*MxSmb[i].smb3.lotbuy;

            if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)>(MxSmb[i].smb1.mrg+MxSmb[i].smb2.mrg+MxSmb[i].smb3.mrg)*CF)
               fnOpen(MxSmb,i,true,lcOpenThree);
           }
         else

         if(MxSmb[i].PLSell>MxSmb[i].spreadsell && nnAllowSell && mmAllowSell)
           {
            MxSmb[i].smb3.mrg=MarketInfo(MxSmb[i].smb3.name,MODE_MARGINREQUIRED)*MxSmb[i].smb3.lotsell;

            if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)>(MxSmb[i].smb1.mrg+MxSmb[i].smb2.mrg+MxSmb[i].smb3.mrg)*CF)
               fnOpen(MxSmb,i,false,lcOpenThree);
           }

         // abrimos el triangulo
         if(MxSmb[i].status==1)
            Print("Open triangle: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" magic: "+(string)MxSmb[i].magic);
        }
     }//for i
  }
//+------------------------------------------------------------------+
//mira libre mago
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int fnMagicGet(stThree & MxSmb[],int magic)
  {
   bool find;

// puede iterar sobre todos los triángulos abiertos en la matriz de mezcla
// Elegí otra opción: pasar por la gama de magos, me parece más rápido
// y mago ya seleccionado para conducir a través de la matriz
   for(int i=magic;i<magic+MAGIC;i++)
     {
      find=false;

      // mago en i. comprobar si está asignado a algún triángulo desde abierto
      for(int j=OrdersTotal()-1;j>=0;j--)
         if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
            if(OrderMagicNumber()==i)
              {
               find=true;
               break;
              }

      // si no se usa el mago, salga del ciclo sin esperar a que termine   
      if(!find) return(i);
     }
   return(0);
  }
//+------------------------------------------------------------------+
//consideramos ganancias y pérdidas y las enviamos para cerrar

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnCalcPL(stThree &MxSmb[],double prft,int fh)
  {
// De nuevo recorremos nuestro array de triángulos
// La velocidad de la apertura y del cierre es muy importante para esta estrategia. 
// Por eso, en cuanto encontramos un triángulo para el cierre, lo cerramos inmediatamente.

   bool flag=TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)&AccountInfoInteger(ACCOUNT_TRADE_EXPERT)&AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)&TerminalInfoInteger(TERMINAL_CONNECTED);
   if(!flag) return;

   for(int i=ArraySize(MxSmb)-1;i>=0;i--)
     {//for
      // Nos interesan solamente los triángulos con el estatus 2 o 3.
      // El estatus 3 (cerrar el triángulo) hemos podido obtener si el triángulo no se abierto completamente
      if(MxSmb[i].status<=1) continue;

      // calculemos cuánto ganó el triángulo
      if(MxSmb[i].status==2)
        {
         MxSmb[i].pl=0;// Reseteamos el beneficio

         if(OrderSelect(MxSmb[i].smb1.tkt,SELECT_BY_TICKET,MODE_TRADES) && OrderCloseTime()==0) MxSmb[i].pl+=OrderProfit();
         else
           {
            MxSmb[i].status=3;
            fnCloseThree(MxSmb,i,fh);
            continue;
           }
         if(OrderSelect(MxSmb[i].smb2.tkt,SELECT_BY_TICKET,MODE_TRADES) && OrderCloseTime()==0) MxSmb[i].pl+=OrderProfit();
         else
           {
            MxSmb[i].status=3;
            fnCloseThree(MxSmb,i,fh);
            continue;
           }
         if(OrderSelect(MxSmb[i].smb3.tkt,SELECT_BY_TICKET,MODE_TRADES) && OrderCloseTime()==0) MxSmb[i].pl+=OrderProfit();
         else
           {
            MxSmb[i].status=3;
            fnCloseThree(MxSmb,i,fh);
            continue;
           }

         // Redondeamos hasta el dígito 2.
         MxSmb[i].pl=NormalizeDouble(MxSmb[i].pl,2);

         // El cierre lo vamos a analizar más detalladamente. Yo uso la siguiente lógica:
         // la situación con el arbitraje no es normal y no debe surgir, es decir, cuando aparece podemos aspirar a la vuelta 
         // en el estado cuando no hay arbitraje. ¿Podremos ganar? En otras palabras, no podemos decir 
         // si la obtención del beneficio continua. Por eso yo prefiero cerrar la posición inmediatamente después de que el spred y la comisión queden cubiertos. 
         // La cuenta en el arbitraje triangular va en puntos, aquí no hay que esperar grandes movimientos. 
         // No obstante, puede poner el beneficio deseado en la variable «Comisión» en los parámetros de entrada, y esperar a que llegue. 
         // Concluyendo, si hemos ganado más de que hemos gastado, asignamos a la posición el estatus «enviar para el cierre».
         if(MxSmb[i].pl>prft && MxSmb[i].pl>0) MxSmb[i].status=3;
        }

      // Cerrar el triángulo sólo si el trading está permitido.
      if(MxSmb[i].status==3) fnCloseThree(MxSmb,i,fh);
     }//for         
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void fnCreateFileSymbols(stThree &MxSmb[],int filehandle)
  {
// definir encabezados en el archivo
   FileWrite(filehandle,"Symbol 1","Symbol 2","Symbol 3","Contract Size 1","Contract Size 2","Contract Size 3",
             "Lot min 1","Lot min 2","Lot min 3","Lot max 1","Lot max 2","Lot max 3","Lot step 1","Lot step 2","Lot step 3",
             "Digits 1","Digits 2","Digits 3");

// llenar el archivo de acuerdo con los encabezados anteriores
   for(int i=ArraySize(MxSmb)-1;i>=0;i--)
     {
      FileWrite(filehandle,MxSmb[i].smb1.name,MxSmb[i].smb2.name,MxSmb[i].smb3.name,
                MxSmb[i].smb1.contract,MxSmb[i].smb2.contract,MxSmb[i].smb3.contract,
                MxSmb[i].smb1.lot_min,MxSmb[i].smb2.lot_min,MxSmb[i].smb3.lot_min,
                MxSmb[i].smb1.lot_max,MxSmb[i].smb2.lot_max,MxSmb[i].smb3.lot_max,
                MxSmb[i].smb1.lot_step,MxSmb[i].smb2.lot_step,MxSmb[i].smb3.lot_step,
                MxSmb[i].smb1.digits,MxSmb[i].smb2.digits,MxSmb[i].smb3.digits);
     }
   FileWrite(filehandle,"");//deja una cadena vacía después de todos los caracteres

                            // después de completar el trabajo, restableceremos todos los datos en el disco, por seguridad
   FileFlush(filehandle);
  }
//+------------------------------------------------------------------+
//Inmediatamente después de abrir, escribimos toda la información en un archivo para que pueda verificar y verificar

void fnControlFile(stThree &MxSmb[],int i,int fh)
  {
   FileWrite(fh,"============");
   FileWrite(fh,"Open:",MxSmb[i].smb1.name,MxSmb[i].smb2.name,MxSmb[i].smb3.name);
   FileWrite(fh,"Tiket:",MxSmb[i].smb1.tkt,MxSmb[i].smb2.tkt,MxSmb[i].smb3.tkt);
   FileWrite(fh,"Lot",DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot),DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot),DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot),DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot));
   FileWrite(fh,"Margin",DoubleToString(MxSmb[i].smb1.mrg,2),DoubleToString(MxSmb[i].smb2.mrg,2),DoubleToString(MxSmb[i].smb3.mrg,2));
   FileWrite(fh,"Ask",DoubleToString(MxSmb[i].smb1.tick.ask,MxSmb[i].smb1.digits),DoubleToString(MxSmb[i].smb2.tick.ask,MxSmb[i].smb2.digits),DoubleToString(MxSmb[i].smb3.tick.ask,MxSmb[i].smb3.digits));
   FileWrite(fh,"Bid",DoubleToString(MxSmb[i].smb1.tick.bid,MxSmb[i].smb1.digits),DoubleToString(MxSmb[i].smb2.tick.bid,MxSmb[i].smb2.digits),DoubleToString(MxSmb[i].smb3.tick.bid,MxSmb[i].smb3.digits));
   FileWrite(fh,"Tick value",DoubleToString(MxSmb[i].smb1.tv,MxSmb[i].smb1.digits),DoubleToString(MxSmb[i].smb2.tv,MxSmb[i].smb2.digits),DoubleToString(MxSmb[i].smb3.tv,MxSmb[i].smb3.digits));
   FileWrite(fh,"Spread point",DoubleToString(MxSmb[i].smb1.sppoint,0),DoubleToString(MxSmb[i].smb2.sppoint,0),DoubleToString(MxSmb[i].smb3.sppoint,0));
   FileWrite(fh,"PL Buy",DoubleToString(MxSmb[i].PLBuy,3));
   FileWrite(fh,"PL Sell",DoubleToString(MxSmb[i].PLSell,3));
   FileWrite(fh,"Magic",string(MxSmb[i].magic));
   FileWrite(fh,"Time open",TimeToString(MxSmb[i].timeopen,TIME_DATE|TIME_SECONDS));
   FileWrite(fh,"Time current",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));

   FileFlush(fh);
  }
//+------------------------------------------------------------------+
//cerrando un triángulo específicamente
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnCloseThree(stThree &MxSmb[],int i,int fh)
  {
// antes de cerrar, asegúrese de verificar la disponibilidad de todos los pares en el triángulo
// romper un triángulo es extremadamente incorrecto y peligroso, y si trabajas en una cuenta de compensación
// entonces en el futuro no será posible lidiar con el caos que ocurrirá en las posiciones

   if(!fnSmbCheck(MxSmb[i].smb1.name)) return;
   if(!fnSmbCheck(MxSmb[i].smb2.name)) return;
   if(!fnSmbCheck(MxSmb[i].smb3.name)) return;

// si todo está disponible, entonces usando la biblioteca estándar cerramos las 3 posiciones
// después de cerrar, nuevamente, debe verificar el éxito de la acción 

   MqlTick tk;

   if(MxSmb[i].smb1.tkt>0)
     {
      if(OrderSelect(MxSmb[i].smb1.tkt,SELECT_BY_TICKET,MODE_TRADES))
        {
         if(OrderCloseTime()==0 && SymbolInfoTick(MxSmb[i].smb1.name,tk))
           {
            if(OrderType()==OP_BUY)
              {
               if(OrderClose(MxSmb[i].smb1.tkt,OrderLots(),NormalizeDouble(tk.bid,MxSmb[i].smb1.digits),100))
                  MxSmb[i].smb1.tkt=0;
              }
            else
            if(OrderType()==OP_SELL)
            if(OrderClose(MxSmb[i].smb1.tkt,OrderLots(),NormalizeDouble(tk.ask,MxSmb[i].smb1.digits),100))
               MxSmb[i].smb1.tkt=0;
           }
         else MxSmb[i].smb1.tkt=0;
        }
      else MxSmb[i].smb1.tkt=0;
     }

   if(MxSmb[i].smb2.tkt>0)
     {
      if(OrderSelect(MxSmb[i].smb2.tkt,SELECT_BY_TICKET,MODE_TRADES))
        {
         if(OrderCloseTime()==0 && SymbolInfoTick(MxSmb[i].smb2.name,tk))
           {
            if(OrderType()==OP_BUY)
              {
               if(OrderClose(MxSmb[i].smb2.tkt,OrderLots(),NormalizeDouble(tk.bid,MxSmb[i].smb2.digits),100))
                  MxSmb[i].smb2.tkt=0;
              }
            else
            if(OrderType()==OP_SELL)
            if(OrderClose(MxSmb[i].smb2.tkt,OrderLots(),NormalizeDouble(tk.ask,MxSmb[i].smb2.digits),100))
               MxSmb[i].smb2.tkt=0;
           }
         else MxSmb[i].smb2.tkt=0;
        }
      else MxSmb[i].smb2.tkt=0;
     }

   if(MxSmb[i].smb3.tkt>0)
     {
      if(OrderSelect(MxSmb[i].smb3.tkt,SELECT_BY_TICKET,MODE_TRADES))
        {
         if(OrderCloseTime()==0 && SymbolInfoTick(MxSmb[i].smb3.name,tk))
           {
            if(OrderType()==OP_BUY)
              {
               if(OrderClose(MxSmb[i].smb3.tkt,OrderLots(),NormalizeDouble(tk.bid,MxSmb[i].smb3.digits),100))
                  MxSmb[i].smb3.tkt=0;
              }
            else
            if(OrderType()==OP_SELL)
            if(OrderClose(MxSmb[i].smb3.tkt,OrderLots(),NormalizeDouble(tk.ask,MxSmb[i].smb3.digits),100))
               MxSmb[i].smb3.tkt=0;
           }
         else MxSmb[i].smb3.tkt=0;
        }
      else MxSmb[i].smb3.tkt=0;
     }

   Print("Close triangle: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+" magic: "+(string)MxSmb[i].magic+"  P/L: "+DoubleToString(MxSmb[i].pl,2));

   if(MxSmb[i].smb1.tkt<=0 && MxSmb[i].smb2.tkt<=0 && MxSmb[i].smb3.tkt<=0)
     {
      fnControlFile(MxSmb,i,glFileLog);
      fnUpdateAIScore(MxSmb,i);
      MxSmb[i].smb1.side=0;
      MxSmb[i].smb2.side=0;
      MxSmb[i].smb3.side=0;
      MxSmb[i].status=0;
      MxSmb[i].timeopen=TimeCurrent();

      // información de cierre registrada en un archivo de registro
      if(fh!=INVALID_HANDLE)
        {
         FileWrite(fh,"============");
         FileWrite(fh,"Close:",MxSmb[i].smb1.name,MxSmb[i].smb2.name,MxSmb[i].smb3.name);
         FileWrite(fh,"Lot",DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot),DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot),DoubleToString(MxSmb[i].smb3.lotbuy,MxSmb[i].smb3.digits_lot),DoubleToString(MxSmb[i].smb3.lotsell,MxSmb[i].smb3.digits_lot));
         FileWrite(fh,"Tiket",string(MxSmb[i].smb1.tkt),string(MxSmb[i].smb2.tkt),string(MxSmb[i].smb3.tkt));
         FileWrite(fh,"Magic",string(MxSmb[i].magic));
         FileWrite(fh,"Profit",DoubleToString(MxSmb[i].pl,3));
         FileWrite(fh,"Time current",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
         FileFlush(fh);
        }
     }
  }   
//+------------------------------------------------------------------+


//solo mostrar comentarios en la pantalla

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnCmnt(stThree &MxSmb[],ushort lcOpenThree)
  {


   int total=ArraySize(MxSmb);

   string line="=============================\n";

   string txt=line+MQLInfoString(MQL_PROGRAM_NAME)+": ON\n";
   txt=txt+"Total triángulo: "+(string)total+"\n";
   txt=txt+"Abrir triángulo: "+(string)lcOpenThree+"\n"+line;
   
#ifdef DEMODOSTUP
   txt=txt+"Demo mode\nUse only: EURUSD+EURGBP+GBPUSD\n"+ line;
#endif       
// tantos triángulos como sea posible
   short max=7;
   max=(short)MathMin(total,max);

//salida 5 más cercana


   txt=txt+"Divisa1           Divisa2           Divisa3         P/L Buy        P/L Sell         Spread\n";
  
   
   for(int i=0;i<total;i++)
     {
      if(MxSmb[i].status!=0) continue;

      txt=txt+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+":";
      txt=txt+"      "+DoubleToString(MxSmb[i].PLBuy,2)+"          "+DoubleToString(MxSmb[i].PLSell,2)+"            "+DoubleToString((MxSmb[i].spreadbuy+MxSmb[i].spreadsell)/2,2);
      txt=txt+"\n";

      if(--max<=0) break;
     }


// imprimir triángulos abiertos
   txt=txt+line+"\n";
   for(int i=total-1;i>=0;i--)
      if(MxSmb[i].status==2)
        {
         txt=txt+MxSmb[i].smb1.name+"+"+MxSmb[i].smb2.name+"+"+MxSmb[i].smb3.name+" P/L: "+DoubleToString(MxSmb[i].pl,2);
         txt=txt+"  Tiempo Abierto: "+TimeToString(MxSmb[i].timeopen,TIME_DATE|TIME_MINUTES|TIME_SECONDS);
         txt=txt+"\n" ;
        }
                            
   if((bool)MQLInfoInteger(MQL_TESTER)) txt="EA es una moneda múltiple y el modo de prueba no es compatible";
   Comment(txt);
   fnDrawRightPanel(MxSmb,lcOpenThree);
  }
  
 
//+------------------------------------------------------------------+

//la brecha con el robot no es terrible ya que las variables permanecen. pero al reiniciar, necesita encontrar órdenes abiertas y
//llevarlos al entorno actual del robot
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void fnRestart(stThree &MxSmb[],int magic)
  {
   string   smb1,smb2,smb3;
   int      tkt1,tkt2,tkt3;
   int      mg;
   uchar    count=0;    //contador de triángulos restaurados

                        // con una cuenta de cobertura, es fácil restaurar posiciones: revisa todo lo abierto, usa tu magia para encontrar la tuya y 
// luego formarlos en triángulos
// con la red es más difícil: debe recurrir a su propia base de datos en la que se almacenan las posiciones abiertas por el robot

// Se implementa el algoritmo para encontrar sus posiciones y restaurarlas en un triángulo: frente, sin adornos y 
// mejoramiento. Pero como esta etapa no suele ser necesaria, el rendimiento puede descuidarse por el bien de
// abreviaturas de código

// iterar sobre todas las posiciones abiertas y ver la coincidencia de la magia
// también necesitamos recordar al mago de la primera posición encontrada, porque los otros dos
// buscaremos específicamente esta magia

   for(int i=OrdersTotal()-1;i>=2;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {//for i
         smb1=OrderSymbol();
         mg=OrderMagicNumber();
         if(mg<magic || mg>(magic+MAGIC)) continue;

         // recuerde el boleto para facilitar el acceso a esta posición
         tkt1=OrderTicket();

         // Ahora estamos buscando una segunda posición en la que el mismo mago
         for(int j=i-1;j>=1;j--)
            if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
              {//for j
               smb2=OrderSymbol();
               if(mg!=OrderMagicNumber()) continue;
               tkt2=OrderTicket();

               // queda por encontrar la última posición
               for(int k=j-1;k>=0;k--)
                  if(OrderSelect(k,SELECT_BY_POS,MODE_TRADES))
                    {//for k
                     smb3=OrderSymbol();
                     if(mg!=OrderMagicNumber()) continue;
                     tkt3=OrderTicket();

                     // si viniste aquí, entonces encontraste un triángulo abierto. Los datos ya están cargados, nos queda 
                     // solo dile al robot que este triángulo ya está abierto. El robot calculará el resto en la próxima marca

                     for(int m=ArraySize(MxSmb)-1;m>=0;m--)
                       {//for m
                        // repasemos la matriz de triángulos, ignorando los que ya están abiertos
                        if(MxSmb[m].status!=0) continue;

                        // fuerza bruta - áspera pero rápida
                        // a primera vista puede parecer que en esta comparación podemos pasar varias veces a 
                        // el mismo par de divisas Sin embargo, esto no es así, porque en los ciclos de búsqueda que son más altos, 
                        // después de encontrar otro par de divisas, continuamos buscando más, desde el próximo par, y no
                        // desde el principio.
                        if((MxSmb[m].smb1.name==smb1 || MxSmb[m].smb1.name==smb2 || MxSmb[m].smb1.name==smb3) && 
                           (MxSmb[m].smb2.name==smb1 || MxSmb[m].smb2.name==smb2 || MxSmb[m].smb2.name==smb3) &&
                           (MxSmb[m].smb3.name==smb1 || MxSmb[m].smb3.name==smb2 || MxSmb[m].smb3.name==smb3)); else continue;

                        //luego encontramos este triángulo y le asignamos el estado correspondiente
                        MxSmb[m].status=2;
                        MxSmb[m].magic=magic;
                        MxSmb[m].pl=0;

                        // organizamos los tickets en la secuencia necesaria y eso es todo, el triángulo vuelve a funcionar.
                        if(MxSmb[m].smb1.name==smb1) MxSmb[m].smb1.tkt=tkt1;
                        if(MxSmb[m].smb1.name==smb2) MxSmb[m].smb1.tkt=tkt2;
                        if(MxSmb[m].smb1.name==smb3) MxSmb[m].smb1.tkt=tkt3;

                        if(MxSmb[m].smb2.name==smb1) MxSmb[m].smb2.tkt=tkt1;
                        if(MxSmb[m].smb2.name==smb2) MxSmb[m].smb2.tkt=tkt2;
                        if(MxSmb[m].smb2.name==smb3) MxSmb[m].smb2.tkt=tkt3;

                        if(MxSmb[m].smb3.name==smb1) MxSmb[m].smb3.tkt=tkt1;
                        if(MxSmb[m].smb3.name==smb2) MxSmb[m].smb3.tkt=tkt2;
                        if(MxSmb[m].smb3.name==smb3) MxSmb[m].smb3.tkt=tkt3;

                        MxSmb[m].timeopen=OrderOpenTime();

                        count++;
                        break;
                       }//for m              
                    }//for k              
              }//for j         
        }//for i         

   if(count>0) Print("Restore "+(string)count+" Triangulos");
  }
//+------------------------------------------------------------------+
//todo descubrimiento aquí

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool fnOpen(stThree &MxSmb[],int i,bool side,ushort &opt)
  {
   MxSmb[i].timeopen=TimeCurrent();

// bandera de abrir el primer pedido
   bool openflag=false;

// если нет разрешения на торговлю то и не торгуем
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return(false);
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return(false);
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return(false);
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) return(false);

#ifdef DEMODOSTUP
   if(MxSmb[i].smb1.base!="EUR") return(false);
   if(MxSmb[i].smb1.prft!="USD") return(false);

   if(MxSmb[i].smb2.base!="EUR") return(false);
   if(MxSmb[i].smb2.prft!="GBP") return(false);

   if(MxSmb[i].smb3.base!="GBP") return(false);
   if(MxSmb[i].smb3.prft!="USD") return(false);
   
   if(MxSmb[i].smb1.base!="EUR") return(false);
   if(MxSmb[i].smb1.prft!="CHF") return(false);

   if(MxSmb[i].smb2.base!="USD") return(false);
   if(MxSmb[i].smb2.prft!="JPY") return(false);

   if(MxSmb[i].smb3.base!="CHF") return(false);
   if(MxSmb[i].smb3.prft!="JPY") return(false);
   
   if(MxSmb[i].smb1.base!="AUD") return(false);
   if(MxSmb[i].smb1.prft!="GBP") return(false);

   if(MxSmb[i].smb2.base!="USD") return(false);
   if(MxSmb[i].smb2.prft!="CHF") return(false);

   if(MxSmb[i].smb3.base!="GBP") return(false);
   if(MxSmb[i].smb3.prft!="CHF") return(false);
   
   if(MxSmb[i].smb1.base!="NZD") return(false);
   if(MxSmb[i].smb1.prft!="USD") return(false);

   if(MxSmb[i].smb2.base!="CAD") return(false);
   if(MxSmb[i].smb2.prft!="NZD") return(false);

   if(MxSmb[i].smb3.base!="NZD") return(false);
   if(MxSmb[i].smb3.prft!="CHF") return(false);
   
#endif 

   MxSmb[i].smb1.tkt=0;
   MxSmb[i].smb2.tkt=0;
   MxSmb[i].smb3.tkt=0;

   switch(side)
     {
      case  true:

         // si se devuelve verdadero después de enviar la orden de apertura, esto no es una garantía de que se abrirá
         // pero si la falsedad regresó, definitivamente no la abriremos desde orden ni siquiera enviada
         // por lo tanto, no tiene sentido enviar los otros 2 pares para su apertura. Mejor inténtalo de nuevo en la próxima marca
         // Además, el robot no abre el triángulo. Pedidos enviados, si algo no se abre, luego de esperar
         // el tiempo especificado en la definición MAXTIMEWAIT, cierre el triángulo si aún no se abrió hasta el final

         MxSmb[i].smb1.tkt=OrderSend(MxSmb[i].smb1.name,OP_BUY,MxSmb[i].smb1.lot,NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_ASK),(int)SymbolInfoInteger(MxSmb[i].smb1.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxSmb[i].cmnt,MxSmb[i].magic,0,clrBlue);
         if(MxSmb[i].smb1.tkt>0)
           {
            MxSmb[i].status=1;
            opt++;
            // entonces la lógica es la misma: si no se pueden abrir, el triángulo se bloqueará    
            MxSmb[i].smb2.tkt=OrderSend(MxSmb[i].smb2.name,OP_SELL,MxSmb[i].smb2.lot,NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_BID),(int)SymbolInfoInteger(MxSmb[i].smb2.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxSmb[i].cmnt,MxSmb[i].magic,0,clrRed);
            if(MxSmb[i].smb2.tkt>0)
              {
               MxSmb[i].smb3.tkt=OrderSend(MxSmb[i].smb3.name,OP_SELL,MxSmb[i].smb3.lotsell,NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_BID),(int)SymbolInfoInteger(MxSmb[i].smb3.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxSmb[i].cmnt,MxSmb[i].magic,0,clrRed);
               if(MxSmb[i].smb3.tkt>0) openflag=true;
              }
            MxSmb[i].smb1.side=1;
            MxSmb[i].smb2.side=-1;
            MxSmb[i].smb3.side=-1;
           }
         break;
      case  false:

         MxSmb[i].smb1.tkt=OrderSend(MxSmb[i].smb1.name,OP_SELL,MxSmb[i].smb1.lot,NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_BID),(int)SymbolInfoInteger(MxSmb[i].smb1.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxSmb[i].cmnt,MxSmb[i].magic,0,clrBlue);
         if(MxSmb[i].smb1.tkt>0)
           {
            MxSmb[i].status=1;
            opt++;
            // entonces la lógica es la misma: si no se pueden abrir, el triángulo se bloqueará    
            MxSmb[i].smb2.tkt=OrderSend(MxSmb[i].smb2.name,OP_BUY,MxSmb[i].smb2.lot,NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_ASK),(int)SymbolInfoInteger(MxSmb[i].smb2.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxSmb[i].cmnt,MxSmb[i].magic,0,clrRed);
            if(MxSmb[i].smb2.tkt>0)
              {
               MxSmb[i].smb3.tkt=OrderSend(MxSmb[i].smb3.name,OP_BUY,MxSmb[i].smb3.lotbuy,NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_ASK),(int)SymbolInfoInteger(MxSmb[i].smb3.name,SYMBOL_DIGITS)),DEVIATION,0,0,MxSmb[i].cmnt,MxSmb[i].magic,0,clrRed);
               if(MxSmb[i].smb3.tkt>0) openflag=true;
              }
            MxSmb[i].smb1.side=-1;
            MxSmb[i].smb2.side=1;
            MxSmb[i].smb3.side=1;
           }
         break;
     }

   if(openflag)
     {
      MxSmb[i].status=2;
      fnControlFile(MxSmb,i,glFileLog);
     }
   return(openflag);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

 
