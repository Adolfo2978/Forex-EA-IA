//+------------------------------------------------------------------+
//|          ARBITRAJE TRIANGULAR PRO v3.0 — MQL5 EDITION           |
//|          Motor: IA Adaptativa + Red Neuronal + MM Filter         |
//|          Entorno Gráfico: Panel HUD Profesional Multi-Módulo     |
//+------------------------------------------------------------------+
#property copyright   "Arbitraje Triangular PRO — MQL5"
#property link        "https://www.mql5.com"
#property version     "3.00"
#property description "Sistema de Arbitraje Triangular con IA Adaptativa, Red Neuronal y Panel HUD Profesional"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//===================================================================
// ENUMERACIONES
//===================================================================
enum enMode
{
   STANDART_MODE = 0,  // Símbolos del Mercado (Market Watch)
   USE_FILE      = 1,  // Símbolos desde archivo CSV
   CREATE_FILE   = 2   // Crear archivo de símbolos
};

enum enPanelTheme
{
   THEME_DARK_CYBER  = 0,  // Dark Cyber (Negro/Cian)
   THEME_DARK_GOLD   = 1,  // Dark Gold (Negro/Dorado)
   THEME_MATRIX      = 2,  // Matrix (Negro/Verde)
   THEME_MIDNIGHT    = 3   // Midnight (Azul oscuro/Plata)
};

//===================================================================
// PARÁMETROS DE ENTRADA — TRADING
//===================================================================
input group "=== MODO DE OPERACIÓN ==="
input enMode      inMode          = USE_FILE;    // Modo de trabajo
input double      inProfit        = 2.5;         // Beneficio mínimo (comisión cubierta)
input double      inLot           = 0.01;        // Volumen base de trading
input ushort      inMaxThree      = 5;           // Máximo de triángulos abiertos simultáneos
input int         inMagic         = 300;         // Número mágico base del EA
input string      inCmnt          = "ArbT3 ";   // Comentario de órdenes

input group "=== FILTRO IA ADAPTATIVO ==="
input bool        inUseIA         = true;        // Activar filtro IA adaptativo
input double      inAIAgresividad = 0.35;        // Agresividad IA [0.0 – 1.0]

input group "=== RED NEURONAL ==="
input bool        inUseNeuralNet  = true;        // Activar red neuronal
input int         inNNTrainDays   = 90;          // Días históricos de entrenamiento
input ENUM_TIMEFRAMES inNNTimeframe = PERIOD_M15; // Timeframe intradía
input int         inNNEpochs      = 4;           // Épocas de entrenamiento
input double      inNNLRate       = 0.03;        // Learning rate
input double      inNNBuyThr      = 0.56;        // Umbral compra NN
input double      inNNSellThr     = 0.44;        // Umbral venta NN

input group "=== FILTRO MARKET MAKER ==="
input bool        inUseMMMethod   = true;        // Activar filtro Market Maker

input group "=== PANEL HUD PROFESIONAL ==="
input bool        inPanelVisible  = true;        // Mostrar panel HUD
input enPanelTheme inPanelTheme   = THEME_DARK_CYBER; // Tema del panel
input ENUM_BASE_CORNER inPanelCorner = CORNER_RIGHT_UPPER; // Esquina del panel
input int         inPanelX        = 12;          // Distancia X
input int         inPanelY        = 12;          // Distancia Y
input int         inPanelWidth    = 460;         // Ancho del panel (px)

//===================================================================
// CONSTANTES Y MACROS
//===================================================================
#define DEVIATION       3
#define FILENAME        "ArbT3_Symbols.csv"
#define FILELOG         "ArbT3_Control_"
#define CF              1.30
#define MAGIC_RANGE     200
#define MAXTIMEWAIT     3
#define PAUSESECOND     600

//===================================================================
// ESTRUCTURAS DE DATOS
//===================================================================
struct stSmb
{
   string   name;
   int      digits;
   uchar    digits_lot;
   double   point_inv;    // 1/point para multiplicar en vez de dividir
   double   dev;
   double   lot, lotbuy, lotsell;
   double   lot_min, lot_max, lot_step;
   double   contract;
   double   price;
   int      tkt;
   MqlTick  tick;
   double   tv;           // tick value
   double   mrg;          // margen requerido
   double   sppoint;      // spread en puntos
   double   spcost;       // spread en dinero (lote 1 y 2)
   double   spcostbuy;    // spread en dinero compra (lote 3)
   double   spcostsell;   // spread en dinero venta  (lote 3)
   string   base, prft;
   char     side;         // +1 buy, -1 sell, 0 ninguno
   stSmb() { price=0; tkt=0; mrg=0; side=0; point_inv=10000; }
};

struct stThree
{
   stSmb    smb1, smb2, smb3;
   int      magic;
   string   cmnt;
   uchar    status;       // 0=libre 1=abriendo 2=abierto 3=cerrando
   double   pl;
   datetime timeopen;
   double   PLBuy, PLSell;
   double   spreadbuy, spreadsell;
   // IA
   double   aiScore;
   uint     aiTrades, aiWins, aiLosses;
   double   aiConfidence;
   double   lastPL;
   // NN
   double   nnProb;
   // MM
   double   mmBias;
   stThree() { status=0; magic=0; timeopen=0; aiScore=0;
               aiTrades=0; aiWins=0; aiLosses=0; aiConfidence=0;
               lastPL=0; nnProb=0.5; mmBias=0; pl=0; PLBuy=0; PLSell=0;
               spreadbuy=0; spreadsell=0; }
};

//===================================================================
// VARIABLES GLOBALES
//===================================================================
stThree   MxThree[];
CTrade    g_trade;
int       g_fileLog    = INVALID_HANDLE;

// Red Neuronal
double    g_nnWeights[6] = {0.0, 0.15, -0.08, 0.12, 0.10, -0.05};
bool      g_nnReady      = false;
datetime  g_nnLastTrain  = 0;
double    g_nnAccuracy   = 0.5;
double    g_nnLoss       = 0.0;
double    g_nnSamples    = 0;

// Panel HUD — nombres de objetos
string    g_pfx;   // prefijo único por instancia
// Estadísticas globales del EA
double    g_totalProfit  = 0.0;
int       g_totalTrades  = 0;
datetime  g_startTime;

//===================================================================
// PALETAS DE COLOR POR TEMA
//===================================================================
struct stThemePalette
{
   color bg_dark;     // fondo principal
   color bg_mid;      // fondo secundario
   color bg_light;    // fondo secciones
   color accent1;     // acento principal
   color accent2;     // acento secundario
   color text_hi;     // texto destacado
   color text_lo;     // texto secundario
   color green_hi;    // positivo
   color red_hi;      // negativo
   color border;      // bordes
};

stThemePalette g_theme;

void SetTheme(enPanelTheme t)
{
   switch(t)
   {
      case THEME_DARK_CYBER:
         g_theme.bg_dark   = C'8,12,20';
         g_theme.bg_mid    = C'12,20,32';
         g_theme.bg_light  = C'18,30,50';
         g_theme.accent1   = C'0,220,255';
         g_theme.accent2   = C'0,150,200';
         g_theme.text_hi   = C'200,240,255';
         g_theme.text_lo   = C'80,130,170';
         g_theme.green_hi  = C'0,255,150';
         g_theme.red_hi    = C'255,60,80';
         g_theme.border    = C'0,80,120';
         break;
      case THEME_DARK_GOLD:
         g_theme.bg_dark   = C'10,8,4';
         g_theme.bg_mid    = C'18,14,6';
         g_theme.bg_light  = C'28,22,8';
         g_theme.accent1   = C'255,200,50';
         g_theme.accent2   = C'200,140,20';
         g_theme.text_hi   = C'255,240,200';
         g_theme.text_lo   = C'140,110,50';
         g_theme.green_hi  = C'100,255,100';
         g_theme.red_hi    = C'255,70,50';
         g_theme.border    = C'80,60,10';
         break;
      case THEME_MATRIX:
         g_theme.bg_dark   = C'2,8,2';
         g_theme.bg_mid    = C'4,14,4';
         g_theme.bg_light  = C'6,22,6';
         g_theme.accent1   = C'0,255,70';
         g_theme.accent2   = C'0,180,50';
         g_theme.text_hi   = C'180,255,180';
         g_theme.text_lo   = C'40,120,40';
         g_theme.green_hi  = C'0,255,100';
         g_theme.red_hi    = C'255,50,50';
         g_theme.border    = C'0,60,0';
         break;
      case THEME_MIDNIGHT:
         g_theme.bg_dark   = C'8,10,22';
         g_theme.bg_mid    = C'14,18,38';
         g_theme.bg_light  = C'20,26,55';
         g_theme.accent1   = C'160,180,255';
         g_theme.accent2   = C'100,130,220';
         g_theme.text_hi   = C'220,230,255';
         g_theme.text_lo   = C'80,100,160';
         g_theme.green_hi  = C'80,255,180';
         g_theme.red_hi    = C'255,80,100';
         g_theme.border    = C'40,60,120';
         break;
   }
}

//===================================================================
// HELPERS DE SOPORTE
//===================================================================
double fnClamp(double v, double mn, double mx) { return(v < mn ? mn : v > mx ? mx : v); }
double fnSigmoid(double x) { if(x>35) return 1; if(x<-35) return 0; return 1/(1+MathExp(-x)); }
double fnNNStrength(double p) { return fnClamp(MathAbs(p - 0.5)*2.0, 0.0, 1.0); }

int fnTFMinutes(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 1;   case PERIOD_M5:  return 5;
      case PERIOD_M15: return 15;  case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;  case PERIOD_H4:  return 240;
      case PERIOD_D1:  return 1440; default: return 15;
   }
}

uchar NumberCount(double n)
{
   n = MathAbs(n);
   for(uchar i=0; i<=8; i++)
      if(MathAbs(NormalizeDouble(n,i) - n) <= DBL_EPSILON) return i;
   return 8;
}

//===================================================================
// OnInit
//===================================================================
int OnInit()
{
   if(MQLInfoInteger(MQL_TESTER))
   {
      Print("EA multicurrencia: modo Tester no soportado.");
      Comment("EA multicurrencia: modo Tester no soportado.");
      ExpertRemove();
      return INIT_FAILED;
   }

   g_startTime = TimeCurrent();
   SetTheme(inPanelTheme);

   // Prefijo único para objetos gráficos
   g_pfx = "AT3_" + IntegerToString(ChartID()) + "_" + IntegerToString(inMagic) + "_";

   Print("=== START: Arbitraje Triangular PRO v3.0 ===");

   if(inLot <= 0) { Alert("Volumen <= 0"); ExpertRemove(); return INIT_FAILED; }

   // Archivo de log
   if(inMode != CREATE_FILE)
   {
      string logName = FILELOG + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
      FileDelete(logName);
      g_fileLog = FileOpen(logName, FILE_UNICODE|FILE_WRITE|FILE_SHARE_READ|FILE_CSV);
      if(g_fileLog == INVALID_HANDLE) Alert("Log no creado");
   }

   // Construir triángulos
   fnSetThree(MxThree, inMode);
   fnChangeThree(MxThree);
   fnSmbLoad(inLot, MxThree);

   if(inMode == CREATE_FILE)
   {
      FileDelete(FILENAME);
      int fh = FileOpen(FILENAME, FILE_UNICODE|FILE_WRITE|FILE_SHARE_READ|FILE_CSV);
      if(fh == INVALID_HANDLE) { Alert("Archivo de símbolos no creado"); ExpertRemove(); return INIT_FAILED; }
      fnCreateFileSymbols(MxThree, fh);
      FileClose(fh);
      Print("Archivo de símbolos creado: " + FILENAME);
      ExpertRemove();
      return INIT_SUCCEEDED;
   }

   if(g_fileLog != INVALID_HANDLE) fnCreateFileSymbols(MxThree, g_fileLog);
   fnRestart(MxThree, inMagic);

   if(inUseNeuralNet) fnTrainNN(MxThree);

   if(ArraySize(MxThree) <= 0) { Print("Sin triángulos válidos."); return INIT_FAILED; }

   EventSetTimer(1);
   fnDrawPanel(MxThree, 0);

   Print("Triángulos cargados: " + IntegerToString(ArraySize(MxThree)));
   return INIT_SUCCEEDED;
}

//===================================================================
// OnDeinit
//===================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   fnDeletePanel();
   if(g_fileLog != INVALID_HANDLE) FileClose(g_fileLog);
   Comment("");
   Print("=== STOP: Arbitraje Triangular PRO v3.0 ===");
}

//===================================================================
// OnTick / OnTimer
//===================================================================
void OnTick()  { fnMainLoop(); }
void OnTimer() { fnMainLoop(); }

void fnMainLoop()
{
   // Re-entrenar NN cada 12 horas
   if(inUseNeuralNet && (TimeCurrent() - g_nnLastTrain) > 43200)
      fnTrainNN(MxThree);

   ushort openThree = 0;
   for(int j = ArraySize(MxThree)-1; j >= 0; j--)
      if(MxThree[j].status != 0) openThree++;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool fridayLate = (dt.day_of_week == 5 && dt.hour >= 15);

   if(!fridayLate)
      if(inMaxThree == 0 || inMaxThree > openThree)
         fnCalcDelta(MxThree, inProfit, inCmnt, inMagic, inLot, inMaxThree, openThree);

   fnCalcPL(MxThree, inProfit, g_fileLog);

   // Reintentar apertura de posiciones pendientes
   for(int i = ArraySize(MxThree)-1; i >= 0; i--)
   {
      if(MxThree[i].status == 1)
      {
         if(MxThree[i].smb1.tkt <= 0)
         {
            string s1 = MxThree[i].smb1.name;
            if(MxThree[i].smb1.side == 1)
               MxThree[i].smb1.tkt = fnOrderSend(s1, ORDER_TYPE_BUY, MxThree[i].smb1.lot,
                  NormalizeDouble(SymbolInfoDouble(s1,SYMBOL_ASK),(int)SymbolInfoInteger(s1,SYMBOL_DIGITS)),
                  DEVIATION, MxThree[i].cmnt, MxThree[i].magic);
            else if(MxThree[i].smb1.side == -1)
               MxThree[i].smb1.tkt = fnOrderSend(s1, ORDER_TYPE_SELL, MxThree[i].smb1.lot,
                  NormalizeDouble(SymbolInfoDouble(s1,SYMBOL_BID),(int)SymbolInfoInteger(s1,SYMBOL_DIGITS)),
                  DEVIATION, MxThree[i].cmnt, MxThree[i].magic);
         }
         if(MxThree[i].smb2.tkt <= 0)
         {
            string s2 = MxThree[i].smb2.name;
            if(MxThree[i].smb2.side == 1)
               MxThree[i].smb2.tkt = fnOrderSend(s2, ORDER_TYPE_BUY, MxThree[i].smb2.lot,
                  NormalizeDouble(SymbolInfoDouble(s2,SYMBOL_ASK),(int)SymbolInfoInteger(s2,SYMBOL_DIGITS)),
                  DEVIATION, MxThree[i].cmnt, MxThree[i].magic);
            else if(MxThree[i].smb2.side == -1)
               MxThree[i].smb2.tkt = fnOrderSend(s2, ORDER_TYPE_SELL, MxThree[i].smb2.lot,
                  NormalizeDouble(SymbolInfoDouble(s2,SYMBOL_BID),(int)SymbolInfoInteger(s2,SYMBOL_DIGITS)),
                  DEVIATION, MxThree[i].cmnt, MxThree[i].magic);
         }
         if(MxThree[i].smb3.tkt <= 0)
         {
            string s3 = MxThree[i].smb3.name;
            double lot3 = (MxThree[i].smb3.side == 1) ? MxThree[i].smb3.lotbuy : MxThree[i].smb3.lotsell;
            if(MxThree[i].smb3.side == 1)
               MxThree[i].smb3.tkt = fnOrderSend(s3, ORDER_TYPE_BUY, lot3,
                  NormalizeDouble(SymbolInfoDouble(s3,SYMBOL_ASK),(int)SymbolInfoInteger(s3,SYMBOL_DIGITS)),
                  DEVIATION, MxThree[i].cmnt, MxThree[i].magic);
            else if(MxThree[i].smb3.side == -1)
               MxThree[i].smb3.tkt = fnOrderSend(s3, ORDER_TYPE_SELL, lot3,
                  NormalizeDouble(SymbolInfoDouble(s3,SYMBOL_BID),(int)SymbolInfoInteger(s3,SYMBOL_DIGITS)),
                  DEVIATION, MxThree[i].cmnt, MxThree[i].magic);
         }
         if(MxThree[i].smb1.tkt > 0 && MxThree[i].smb2.tkt > 0 && MxThree[i].smb3.tkt > 0)
            MxThree[i].status = 2;
         else if(TimeCurrent() - MxThree[i].timeopen > MAXTIMEWAIT)
            MxThree[i].status = 3;
         else continue;
      }
      if(MxThree[i].status == 3) fnCloseThree(MxThree, i, g_fileLog);
   }

   fnDrawPanel(MxThree, openThree);
}

//===================================================================
// ENVÍO DE ÓRDENES MQL5
//===================================================================
int fnOrderSend(string symbol, ENUM_ORDER_TYPE type, double vol, double price,
                int slip, string comment, int magic)
{
   MqlTradeRequest req = {}; MqlTradeResult res = {};
   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = symbol;
   req.volume   = vol;
   req.price    = price;
   req.deviation= slip;
   req.magic    = magic;
   req.comment  = comment;
   req.type     = type;

   ENUM_SYMBOL_TRADE_EXECUTION ex = (ENUM_SYMBOL_TRADE_EXECUTION)
      SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
   req.type_filling = (ex == SYMBOL_TRADE_EXECUTION_EXCHANGE ||
                       ex == SYMBOL_TRADE_EXECUTION_INSTANT  ||
                       ex == SYMBOL_TRADE_EXECUTION_REQUEST)
                      ? ORDER_FILLING_FOK : ORDER_FILLING_IOC;

   if(!::OrderSend(req, res)) return -1;
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED ||
      res.retcode == TRADE_RETCODE_DONE_PARTIAL) return (int)res.order;
   return -1;
}

bool fnOrderClose(ulong ticket, double lots, double price, int slip)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string symbol = PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   MqlTradeRequest req = {}; MqlTradeResult res = {};
   req.action   = TRADE_ACTION_DEAL;
   req.position = ticket;
   req.symbol   = symbol;
   req.volume   = lots;
   req.deviation= slip;
   req.price    = price;
   req.type     = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.type_filling = ORDER_FILLING_IOC;
   if(!::OrderSend(req, res)) return false;
   return res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED;
}

double fnPositionProfit(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_PROFIT);
}

bool fnPositionOpen(ulong ticket)
{
   return PositionSelectByTicket(ticket);
}

int fnPositionType(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return -1;
   return (int)PositionGetInteger(POSITION_TYPE);
}

double fnPositionVolume(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return PositionGetDouble(POSITION_VOLUME);
}

//===================================================================
// UTILIDADES SÍMBOLO
//===================================================================
bool fnSmbCheck(string smb)
{
   if(smb == "") return false;
   if(SymbolInfoInteger(smb, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL) return false;
   if(SymbolInfoInteger(smb, SYMBOL_START_TIME) != 0)      return false;
   if(SymbolInfoInteger(smb, SYMBOL_EXPIRATION_TIME) != 0) return false;
   if(!SymbolInfoInteger(smb, SYMBOL_SELECT))               return false;
   MqlTick tk;
   return SymbolInfoTick(smb, tk);
}

bool fnGetBaseProfit(string smb, string &base, string &prft)
{
   if(!SymbolInfoString(smb, SYMBOL_CURRENCY_BASE,   base)) return false;
   if(!SymbolInfoString(smb, SYMBOL_CURRENCY_PROFIT, prft)) return false;
   if(SymbolInfoInteger(smb, SYMBOL_TRADE_CALC_MODE) == 0)  return true;
   if(StringLen(smb) < 6 || StringLen(prft) != 3)           return false;
   if(base == prft || StringFind(smb, base, 0) < 0 ||
      StringFind(smb, prft, 0) < 3)                          return false;
   base = StringSubstr(smb, 0, 3);
   return base != "";
}

double fnMarginRequired(string smb, double vol)
{
   double margin = 0;
   if(SymbolInfoDouble(smb, SYMBOL_MARGIN_INITIAL, margin) && margin > 0) return margin * vol;
   double ask = 0; double cs = 0;
   long lev = AccountInfoInteger(ACCOUNT_LEVERAGE);
   SymbolInfoDouble(smb, SYMBOL_ASK, ask);
   SymbolInfoDouble(smb, SYMBOL_TRADE_CONTRACT_SIZE, cs);
   if(lev <= 0) lev = 1;
   return (ask * cs * vol) / (double)lev;
}

//===================================================================
// CONSTRUCCIÓN DE TRIÁNGULOS
//===================================================================
void fnSetThree(stThree &MxSmb[], enMode mode)
{
   ArrayFree(MxSmb);
   if(mode == STANDART_MODE || mode == CREATE_FILE) fnGetThreeFromMarketWatch(MxSmb);
   if(mode == USE_FILE)                             fnGetThreeFromFile(MxSmb);
}

void fnGetThreeFromFile(stThree &MxSmb[])
{
   int fh = FileOpen(FILENAME, FILE_UNICODE|FILE_READ|FILE_SHARE_READ|FILE_CSV);
   if(fh == INVALID_HANDLE)
   {
      Print("Archivo " + FILENAME + " no encontrado. Usando Market Watch.");
      fnGetThreeFromMarketWatch(MxSmb);
      return;
   }
   FileSeek(fh, 0, SEEK_SET);
   while(!FileIsLineEnding(fh)) FileReadString(fh);
   while(!FileIsEnding(fh) && !IsStopped())
   {
      string s1 = FileReadString(fh), s2 = FileReadString(fh), s3 = FileReadString(fh);
      if(!fnSmbCheck(s1) || !fnSmbCheck(s2) || !fnSmbCheck(s3))
         { while(!FileIsLineEnding(fh)) FileReadString(fh); continue; }
      int cnt = ArraySize(MxSmb);
      ArrayResize(MxSmb, cnt+1);
      MxSmb[cnt].smb1.name = s1; MxSmb[cnt].smb2.name = s2; MxSmb[cnt].smb3.name = s3;
      string b,p;
      fnGetBaseProfit(s1,b,p); MxSmb[cnt].smb1.base=b; MxSmb[cnt].smb1.prft=p;
      fnGetBaseProfit(s2,b,p); MxSmb[cnt].smb2.base=b; MxSmb[cnt].smb2.prft=p;
      fnGetBaseProfit(s3,b,p); MxSmb[cnt].smb3.base=b; MxSmb[cnt].smb3.prft=p;
      while(!FileIsLineEnding(fh)) FileReadString(fh);
   }
   FileClose(fh);
}

void fnGetThreeFromMarketWatch(stThree &MxSmb[])
{
   int total = SymbolsTotal(true);
   for(int i = 0; i < total-2 && !IsStopped(); i++)
   {
      string sm1 = SymbolName(i, true);
      if(!fnSmbCheck(sm1)) continue;
      string b1="",p1=""; if(!fnGetBaseProfit(sm1,b1,p1)) continue;
      for(int j = i+1; j < total-1 && !IsStopped(); j++)
      {
         string sm2 = SymbolName(j, true);
         if(!fnSmbCheck(sm2)) continue;
         string b2="",p2=""; if(!fnGetBaseProfit(sm2,b2,p2)) continue;
         if(b1!=b2 && b1!=p2 && p1!=b2 && p1!=p2) continue;
         for(int k = j+1; k < total && !IsStopped(); k++)
         {
            string sm3 = SymbolName(k, true);
            if(!fnSmbCheck(sm3)) continue;
            string b3="",p3=""; if(!fnGetBaseProfit(sm3,b3,p3)) continue;
            if(b3!=b1 && b3!=p1 && b3!=b2 && b3!=p2) continue;
            if(p3!=b1 && p3!=p1 && p3!=b2 && p3!=p2) continue;
            if(b1==b2&&p1==p2) continue; if(b1==b3&&p1==p3) continue; if(b2==b3&&p2==p3) continue;
            int cnt = ArraySize(MxSmb); ArrayResize(MxSmb, cnt+1);
            MxSmb[cnt].smb1.name=sm1; MxSmb[cnt].smb2.name=sm2; MxSmb[cnt].smb3.name=sm3;
            MxSmb[cnt].smb1.base=b1; MxSmb[cnt].smb1.prft=p1;
            MxSmb[cnt].smb2.base=b2; MxSmb[cnt].smb2.prft=p2;
            MxSmb[cnt].smb3.base=b3; MxSmb[cnt].smb3.prft=p3;
            break;
         }
      }
   }
}

void fnChangeThree(stThree &MxSmb[])
{
   for(int i = ArraySize(MxSmb)-1; i >= 0; i--)
   {
      if(MxSmb[i].smb1.base != MxSmb[i].smb2.base)
      {
         if(MxSmb[i].smb1.base == MxSmb[i].smb3.base)
         {
            string t=MxSmb[i].smb2.name; MxSmb[i].smb2.name=MxSmb[i].smb3.name; MxSmb[i].smb3.name=t;
            string b,p;
            fnGetBaseProfit(MxSmb[i].smb2.name,b,p); MxSmb[i].smb2.base=b; MxSmb[i].smb2.prft=p;
            fnGetBaseProfit(MxSmb[i].smb3.name,b,p); MxSmb[i].smb3.base=b; MxSmb[i].smb3.prft=p;
         }
         if(MxSmb[i].smb2.base == MxSmb[i].smb3.base)
         {
            string t=MxSmb[i].smb1.name; MxSmb[i].smb1.name=MxSmb[i].smb3.name; MxSmb[i].smb3.name=t;
            string b,p;
            fnGetBaseProfit(MxSmb[i].smb1.name,b,p); MxSmb[i].smb1.base=b; MxSmb[i].smb1.prft=p;
            fnGetBaseProfit(MxSmb[i].smb3.name,b,p); MxSmb[i].smb3.base=b; MxSmb[i].smb3.prft=p;
         }
      }
      if(MxSmb[i].smb3.base != MxSmb[i].smb2.prft)
      {
         string t=MxSmb[i].smb1.name; MxSmb[i].smb1.name=MxSmb[i].smb2.name; MxSmb[i].smb2.name=t;
         string b,p;
         fnGetBaseProfit(MxSmb[i].smb1.name,b,p); MxSmb[i].smb1.base=b; MxSmb[i].smb1.prft=p;
         fnGetBaseProfit(MxSmb[i].smb2.name,b,p); MxSmb[i].smb2.base=b; MxSmb[i].smb2.prft=p;
      }
   }
}

void fnSmbLoad(double lot, stThree &MxSmb[])
{
   for(int i = ArraySize(MxSmb)-1; i >= 0; i--)
   {
      // smb1
      if(!fnSmbCheck(MxSmb[i].smb1.name)) { MxSmb[i].smb1.name=""; continue; }
      MxSmb[i].smb1.digits    = (int)SymbolInfoInteger(MxSmb[i].smb1.name, SYMBOL_DIGITS);
      MxSmb[i].smb1.dev       = DEVIATION * SymbolInfoDouble(MxSmb[i].smb1.name, SYMBOL_TRADE_TICK_SIZE);
      double pnt = SymbolInfoDouble(MxSmb[i].smb1.name, SYMBOL_TRADE_TICK_SIZE);
      if(pnt > 0) MxSmb[i].smb1.point_inv = NormalizeDouble(1.0/pnt, 0);
      MxSmb[i].smb1.digits_lot = NumberCount(SymbolInfoDouble(MxSmb[i].smb1.name, SYMBOL_VOLUME_STEP));
      MxSmb[i].smb1.lot_min   = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_VOLUME_MIN), MxSmb[i].smb1.digits_lot);
      MxSmb[i].smb1.lot_max   = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_VOLUME_MAX), MxSmb[i].smb1.digits_lot);
      MxSmb[i].smb1.lot_step  = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb1.name,SYMBOL_VOLUME_STEP),MxSmb[i].smb1.digits_lot);
      MxSmb[i].smb1.contract  = SymbolInfoDouble(MxSmb[i].smb1.name, SYMBOL_TRADE_CONTRACT_SIZE);
      // smb2
      if(!fnSmbCheck(MxSmb[i].smb2.name)) { MxSmb[i].smb1.name=""; continue; }
      MxSmb[i].smb2.digits    = (int)SymbolInfoInteger(MxSmb[i].smb2.name, SYMBOL_DIGITS);
      MxSmb[i].smb2.dev       = DEVIATION * SymbolInfoDouble(MxSmb[i].smb2.name, SYMBOL_TRADE_TICK_SIZE);
      pnt = SymbolInfoDouble(MxSmb[i].smb2.name, SYMBOL_TRADE_TICK_SIZE);
      if(pnt > 0) MxSmb[i].smb2.point_inv = NormalizeDouble(1.0/pnt, 0);
      MxSmb[i].smb2.digits_lot = NumberCount(SymbolInfoDouble(MxSmb[i].smb2.name, SYMBOL_VOLUME_STEP));
      MxSmb[i].smb2.lot_min   = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_VOLUME_MIN), MxSmb[i].smb2.digits_lot);
      MxSmb[i].smb2.lot_max   = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_VOLUME_MAX), MxSmb[i].smb2.digits_lot);
      MxSmb[i].smb2.lot_step  = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_VOLUME_STEP),MxSmb[i].smb2.digits_lot);
      MxSmb[i].smb2.contract  = SymbolInfoDouble(MxSmb[i].smb2.name, SYMBOL_TRADE_CONTRACT_SIZE);
      // smb3
      if(!fnSmbCheck(MxSmb[i].smb3.name)) { MxSmb[i].smb1.name=""; continue; }
      MxSmb[i].smb3.digits    = (int)SymbolInfoInteger(MxSmb[i].smb3.name, SYMBOL_DIGITS);
      MxSmb[i].smb3.dev       = DEVIATION * SymbolInfoDouble(MxSmb[i].smb3.name, SYMBOL_TRADE_TICK_SIZE);
      pnt = SymbolInfoDouble(MxSmb[i].smb3.name, SYMBOL_TRADE_TICK_SIZE);
      if(pnt > 0) MxSmb[i].smb3.point_inv = NormalizeDouble(1.0/pnt, 0);
      MxSmb[i].smb3.digits_lot = NumberCount(SymbolInfoDouble(MxSmb[i].smb3.name, SYMBOL_VOLUME_STEP));
      MxSmb[i].smb3.lot_min   = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_VOLUME_MIN), MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lot_max   = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_VOLUME_MAX), MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lot_step  = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb3.name,SYMBOL_VOLUME_STEP),MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.contract  = SymbolInfoDouble(MxSmb[i].smb3.name, SYMBOL_TRADE_CONTRACT_SIZE);
      // Volúmenes
      MxSmb[i].smb1.lot = NormalizeDouble(lot, MxSmb[i].smb1.digits_lot);
      MxSmb[i].smb2.lot = NormalizeDouble(MxSmb[i].smb1.lot * MxSmb[i].smb1.contract / MxSmb[i].smb2.contract, MxSmb[i].smb2.digits_lot);
      MxSmb[i].smb3.lotbuy  = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_ASK) * MxSmb[i].smb2.lot * MxSmb[i].smb2.contract / MxSmb[i].smb3.contract, MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lotsell = NormalizeDouble(SymbolInfoDouble(MxSmb[i].smb2.name,SYMBOL_BID) * MxSmb[i].smb2.lot * MxSmb[i].smb2.contract / MxSmb[i].smb3.contract, MxSmb[i].smb3.digits_lot);

      Print("Triángulo: "+MxSmb[i].smb1.name+" + "+MxSmb[i].smb2.name+" + "+MxSmb[i].smb3.name+
            " | L1:"+DoubleToString(MxSmb[i].smb1.lot,MxSmb[i].smb1.digits_lot)+
            " L2:"+DoubleToString(MxSmb[i].smb2.lot,MxSmb[i].smb2.digits_lot));
   }
}

//===================================================================
// RED NEURONAL
//===================================================================
double fnEMAFromClose(string smb, ENUM_TIMEFRAMES tf, int period, int shift)
{
   if(period <= 1) return iClose(smb, tf, shift);
   int warmup = period * 4;
   double ema = iClose(smb, tf, shift + warmup);
   if(ema <= 0) return 0;
   double alpha = 2.0 / (period + 1.0);
   for(int s = shift + warmup - 1; s >= shift; s--)
   {
      double c = iClose(smb, tf, s);
      if(c <= 0) return 0;
      ema = alpha * c + (1.0 - alpha) * ema;
   }
   return ema;
}

double fnRSIFromClose(string smb, ENUM_TIMEFRAMES tf, int period, int shift)
{
   double gain = 0, loss = 0;
   for(int k = shift + period; k > shift; k--)
   {
      double d = iClose(smb, tf, k-1) - iClose(smb, tf, k);
      if(d >= 0) gain += d; else loss -= d;
   }
   if(loss <= 0) return 100;
   double rs = (gain/period) / (loss/period);
   return 100 - (100 / (1 + rs));
}

double fnCalcTDI(string smb, ENUM_TIMEFRAMES tf, int shift)
{
   double rsi = fnRSIFromClose(smb, tf, 13, shift);
   double sum = 0; int n = 0;
   for(int k = shift; k < shift+7; k++) { sum += fnRSIFromClose(smb, tf, 13, k); n++; }
   if(n <= 0) return 0;
   return (rsi - sum/n) / 20.0;
}

bool fnBuildNNFeatures(string smb, ENUM_TIMEFRAMES tf, int shift, double spreadPts,
                       double &x1, double &x2, double &x3, double &x4, double &x5)
{
   double p = SymbolInfoDouble(smb, SYMBOL_POINT);
   if(p <= 0) p = 0.0001;
   double e50 = fnEMAFromClose(smb, tf, 50, shift);
   double e200= fnEMAFromClose(smb, tf, 200, shift);
   double e50p= fnEMAFromClose(smb, tf, 50, shift+5);
   double rsi = fnRSIFromClose(smb, tf, 13, shift);
   if(e50<=0 || e200<=0 || e50p<=0) return false;
   x1 = fnClamp((e50 - e200)/(50.0*p),  -3.0, 3.0);
   x2 = fnClamp((e50 - e50p)/(10.0*p),  -3.0, 3.0);
   x3 = fnClamp((rsi - 50.0)/25.0,       -2.0, 2.0);
   x4 = fnClamp(fnCalcTDI(smb,tf,shift), -2.0, 2.0);
   x5 = fnClamp(spreadPts/50.0,           0.0, 2.0);
   return true;
}

bool fnTrainNN(stThree &MxSmb[])
{
   if(ArraySize(MxSmb) <= 0) return false;
   string smb = "";
   int bestBars = 0;
   for(int i = 0; i < ArraySize(MxSmb); i++)
   {
      string c = MxSmb[i].smb1.name;
      if(c == "" || !fnSmbCheck(c)) continue;
      int b = iBars(c, inNNTimeframe);
      if(b > bestBars) { bestBars = b; smb = c; }
   }
   if(smb == "") { Print("NN: sin símbolos válidos"); return false; }

   int tfMin    = fnTFMinutes(inNNTimeframe);
   int needBars = (inNNTrainDays * 1440) / MathMax(tfMin, 1) + 260;
   int bars     = iBars(smb, inNNTimeframe);
   int maxShift = MathMin(bars-3, needBars);
   if(maxShift < 70) { Print("NN: barras insuficientes"); return false; }

   double sumLoss = 0; int samples = 0, correct = 0;
   double l2 = 0.0005;
   for(int e = 0; e < inNNEpochs; e++)
   {
      double decay = (inNNEpochs > 1) ? (double)e/(inNNEpochs-1) : 0;
      double lr = MathMax(inNNLRate*(1-0.35*decay), inNNLRate*0.25);
      for(int sh = maxShift; sh >= 2; sh--)
      {
         double x1,x2,x3,x4,x5;
         double sp = (double)SymbolInfoInteger(smb, SYMBOL_SPREAD);
         if(!fnBuildNNFeatures(smb, inNNTimeframe, sh, sp, x1,x2,x3,x4,x5)) continue;
         double c0 = iClose(smb, inNNTimeframe, sh);
         double c1 = iClose(smb, inNNTimeframe, sh-1);
         if(c0 == 0 || c1 == 0) continue;
         double y    = (c1 > c0) ? 1.0 : 0.0;
         double z    = g_nnWeights[0]+g_nnWeights[1]*x1+g_nnWeights[2]*x2+
                       g_nnWeights[3]*x3+g_nnWeights[4]*x4+g_nnWeights[5]*x5;
         double pred = fnSigmoid(z);
         double err  = fnClamp(y - pred, -1.0, 1.0);
         g_nnWeights[0] += lr * err;
         g_nnWeights[1]  = g_nnWeights[1]*(1-lr*l2) + lr*err*x1;
         g_nnWeights[2]  = g_nnWeights[2]*(1-lr*l2) + lr*err*x2;
         g_nnWeights[3]  = g_nnWeights[3]*(1-lr*l2) + lr*err*x3;
         g_nnWeights[4]  = g_nnWeights[4]*(1-lr*l2) + lr*err*x4;
         g_nnWeights[5]  = g_nnWeights[5]*(1-lr*l2) + lr*err*x5;
         double pp = fnClamp(pred, 0.000001, 0.999999);
         sumLoss += -(y*MathLog(pp) + (1-y)*MathLog(1-pp));
         samples++;
         if((pred>=0.5 && y>0.5) || (pred<0.5 && y<0.5)) correct++;
      }
   }
   g_nnReady     = (samples > 0);
   g_nnLastTrain = TimeCurrent();
   g_nnSamples   = samples;
   g_nnAccuracy  = (samples > 0) ? (double)correct/samples : 0.5;
   g_nnLoss      = (samples > 0) ? sumLoss/samples : 0;
   Print("NN entrenada | samples="+IntegerToString(samples)+
         " acc="+DoubleToString(g_nnAccuracy*100,1)+"%"+
         " loss="+DoubleToString(g_nnLoss,4));
   return g_nnReady;
}

double fnPredictNN(string smb, double spreadPts)
{
   if(!g_nnReady) return 0.5;
   double prob = 0, wsum = 0;
   double ws[3] = {0.60, 0.30, 0.10};
   for(int sh = 0; sh < 3; sh++)
   {
      double x1,x2,x3,x4,x5;
      if(!fnBuildNNFeatures(smb, inNNTimeframe, sh, spreadPts*(1+0.15*sh), x1,x2,x3,x4,x5)) continue;
      double z = g_nnWeights[0]+g_nnWeights[1]*x1+g_nnWeights[2]*x2+
                 g_nnWeights[3]*x3+g_nnWeights[4]*x4+g_nnWeights[5]*x5;
      prob += fnSigmoid(z) * ws[sh]; wsum += ws[sh];
   }
   if(wsum <= 0) return 0.5;
   prob /= wsum;
   double boost = fnClamp((g_nnAccuracy - 0.50)*1.50, 0.0, 0.25);
   prob = 0.5 + (prob - 0.5)*(1 + boost);
   return fnClamp(prob, 0.01, 0.99);
}

//===================================================================
// IA ADAPTATIVA
//===================================================================
void fnUpdateAIScore(stThree &MxSmb[], int idx)
{
   if(idx < 0 || idx >= ArraySize(MxSmb)) return;
   MxSmb[idx].aiTrades++;
   MxSmb[idx].lastPL = MxSmb[idx].pl;
   double outcome = -1.0;
   if(MxSmb[idx].pl > inProfit && MxSmb[idx].pl > 0)
      { outcome = 1.0; MxSmb[idx].aiWins++; }
   else MxSmb[idx].aiLosses++;
   MxSmb[idx].aiScore = fnClamp(0.85*MxSmb[idx].aiScore + 0.15*outcome, -1.0, 1.0);
   g_totalProfit += MxSmb[idx].pl;
   g_totalTrades++;
}

//===================================================================
// CÁLCULO DELTA Y APERTURA
//===================================================================
void fnCalcDelta(stThree &MxSmb[], double prft, string cmnt, int magic,
                 double lot, ushort maxT, ushort &openT)
{
   datetime tm = TimeCurrent();
   for(int i = ArraySize(MxSmb)-1; i >= 0; i--)
   {
      if(MxSmb[i].status != 0) continue;
      if(tm - MxSmb[i].timeopen < PAUSESECOND) continue;
      if(MxSmb[i].smb1.name == "" || MxSmb[i].smb2.name == "" || MxSmb[i].smb3.name == "") continue;
      if(!fnSmbCheck(MxSmb[i].smb1.name)) continue;
      if(!fnSmbCheck(MxSmb[i].smb2.name)) continue;
      if(!fnSmbCheck(MxSmb[i].smb3.name)) continue;
      if(maxT > 0 && maxT <= openT) continue;

      if(!SymbolInfoDouble(MxSmb[i].smb1.name, SYMBOL_TRADE_TICK_VALUE, MxSmb[i].smb1.tv)) continue;
      if(!SymbolInfoDouble(MxSmb[i].smb2.name, SYMBOL_TRADE_TICK_VALUE, MxSmb[i].smb2.tv)) continue;
      if(!SymbolInfoDouble(MxSmb[i].smb3.name, SYMBOL_TRADE_TICK_VALUE, MxSmb[i].smb3.tv)) continue;
      if(!SymbolInfoTick(MxSmb[i].smb1.name, MxSmb[i].smb1.tick)) continue;
      if(!SymbolInfoTick(MxSmb[i].smb2.name, MxSmb[i].smb2.tick)) continue;
      if(!SymbolInfoTick(MxSmb[i].smb3.name, MxSmb[i].smb3.tick)) continue;

      if(MxSmb[i].smb1.tick.ask<=0 || MxSmb[i].smb1.tick.bid<=0 ||
         MxSmb[i].smb2.tick.ask<=0 || MxSmb[i].smb2.tick.bid<=0 ||
         MxSmb[i].smb3.tick.ask<=0 || MxSmb[i].smb3.tick.bid<=0) continue;

      datetime now = TimeCurrent();
      if(now-MxSmb[i].smb1.tick.time>120) continue;
      if(now-MxSmb[i].smb2.tick.time>120) continue;
      if(now-MxSmb[i].smb3.tick.time>120) continue;

      // Volúmenes del tercer par
      MxSmb[i].smb3.lotbuy  = MxSmb[i].smb2.tick.ask * MxSmb[i].smb2.lot * MxSmb[i].smb2.contract / MxSmb[i].smb3.contract;
      MxSmb[i].smb3.lotsell = MxSmb[i].smb2.tick.bid * MxSmb[i].smb2.lot * MxSmb[i].smb2.contract / MxSmb[i].smb3.contract;
      if(MxSmb[i].smb2.prft == "USD") { MxSmb[i].smb3.lotbuy/=100; MxSmb[i].smb3.lotsell/=100; }
      MxSmb[i].smb3.lotbuy  = NormalizeDouble(MxSmb[i].smb3.lotbuy,  MxSmb[i].smb3.digits_lot);
      MxSmb[i].smb3.lotsell = NormalizeDouble(MxSmb[i].smb3.lotsell, MxSmb[i].smb3.digits_lot);

      if(MxSmb[i].smb3.lotbuy  < MxSmb[i].smb3.lot_min || MxSmb[i].smb3.lotbuy  > MxSmb[i].smb3.lot_max) continue;
      if(MxSmb[i].smb3.lotsell < MxSmb[i].smb3.lot_min || MxSmb[i].smb3.lotsell > MxSmb[i].smb3.lot_max) continue;
      if(lot < MxSmb[i].smb1.lot_min || lot > MxSmb[i].smb1.lot_max) continue;

      // Spreads en puntos
      MxSmb[i].smb1.sppoint = NormalizeDouble(MxSmb[i].smb1.tick.ask-MxSmb[i].smb1.tick.bid, MxSmb[i].smb1.digits) * MxSmb[i].smb1.point_inv;
      MxSmb[i].smb2.sppoint = NormalizeDouble(MxSmb[i].smb2.tick.ask-MxSmb[i].smb2.tick.bid, MxSmb[i].smb2.digits) * MxSmb[i].smb2.point_inv;
      MxSmb[i].smb3.sppoint = NormalizeDouble(MxSmb[i].smb3.tick.ask-MxSmb[i].smb3.tick.bid, MxSmb[i].smb3.digits) * MxSmb[i].smb3.point_inv;
      if(MxSmb[i].smb1.sppoint<=0 || MxSmb[i].smb2.sppoint<=0 || MxSmb[i].smb3.sppoint<=0) continue;

      // Costos spread en dinero
      MxSmb[i].smb1.spcost     = MxSmb[i].smb1.sppoint * MxSmb[i].smb1.tv * MxSmb[i].smb1.lot;
      MxSmb[i].smb2.spcost     = MxSmb[i].smb2.sppoint * MxSmb[i].smb2.tv * MxSmb[i].smb2.lot;
      MxSmb[i].smb3.spcostbuy  = MxSmb[i].smb3.sppoint * MxSmb[i].smb3.tv * MxSmb[i].smb3.lotbuy;
      MxSmb[i].smb3.spcostsell = MxSmb[i].smb3.sppoint * MxSmb[i].smb3.tv * MxSmb[i].smb3.lotsell;

      MxSmb[i].spreadbuy  = NormalizeDouble(MxSmb[i].smb1.spcost + MxSmb[i].smb2.spcost + MxSmb[i].smb3.spcostsell + prft, 2);
      MxSmb[i].spreadsell = NormalizeDouble(MxSmb[i].smb1.spcost + MxSmb[i].smb2.spcost + MxSmb[i].smb3.spcostbuy  + prft, 2);

      double temp = MxSmb[i].smb1.tv * MxSmb[i].smb1.point_inv * MxSmb[i].smb1.lot;
      MxSmb[i].PLBuy  = NormalizeDouble(((MxSmb[i].smb2.tick.bid-MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.bid-MxSmb[i].smb3.dev)-(MxSmb[i].smb1.tick.ask+MxSmb[i].smb1.dev))*temp, 2);
      MxSmb[i].PLSell = NormalizeDouble(((MxSmb[i].smb1.tick.bid-MxSmb[i].smb1.dev)-(MxSmb[i].smb2.tick.ask+MxSmb[i].smb2.dev)*(MxSmb[i].smb3.tick.ask+MxSmb[i].smb3.dev))*temp, 2);

      // Confianza IA
      double eBuy = MxSmb[i].PLBuy - MxSmb[i].spreadbuy;
      double eSell= MxSmb[i].PLSell - MxSmb[i].spreadsell;
      double best = MathMax(eBuy,eSell), worst = MathMin(eBuy,eSell);
      double den  = MathAbs(best) + MathAbs(worst) + 0.00001;
      MxSmb[i].aiConfidence = fnClamp(((best-worst)/den)*100.0, 0.0, 100.0);

      bool allowIA = true;
      if(inUseIA)
      {
         double minScore = -0.25 + inAIAgresividad*0.50;
         double minConf  = 20.0  + inAIAgresividad*55.0;
         allowIA = (MxSmb[i].aiScore >= minScore && MxSmb[i].aiConfidence >= minConf);
      }

      // NN + MM
      double sp = (double)SymbolInfoInteger(MxSmb[i].smb1.name, SYMBOL_SPREAD);
      MxSmb[i].nnProb = fnPredictNN(MxSmb[i].smb1.name, sp);
      double e50  = fnEMAFromClose(MxSmb[i].smb1.name, inNNTimeframe, 50, 0);
      double e200 = fnEMAFromClose(MxSmb[i].smb1.name, inNNTimeframe, 200, 0);
      double tdi  = fnCalcTDI(MxSmb[i].smb1.name, inNNTimeframe, 0);
      MxSmb[i].mmBias = 0;
      if(e50 > e200 && tdi > 0) MxSmb[i].mmBias =  1;
      if(e50 < e200 && tdi < 0) MxSmb[i].mmBias = -1;

      double nnStr       = fnNNStrength(MxSmb[i].nnProb);
      double minNNStr    = 0.08 + inAIAgresividad*0.22;
      double dynBuyThr   = fnClamp(inNNBuyThr  - 0.05*(MxSmb[i].aiConfidence/100.0), 0.50, 0.85);
      double dynSellThr  = fnClamp(inNNSellThr + 0.05*(MxSmb[i].aiConfidence/100.0), 0.15, 0.50);
      bool nnBuy  = (!inUseNeuralNet || (MxSmb[i].nnProb >= dynBuyThr  && nnStr >= minNNStr));
      bool nnSell = (!inUseNeuralNet || (MxSmb[i].nnProb <= dynSellThr && nnStr >= minNNStr));
      bool mmBuy  = (!inUseMMMethod  || MxSmb[i].mmBias >= 0);
      bool mmSell = (!inUseMMMethod  || MxSmb[i].mmBias <= 0);

      if((MxSmb[i].PLBuy > MxSmb[i].spreadbuy || MxSmb[i].PLSell > MxSmb[i].spreadsell) && allowIA)
      {
         MxSmb[i].smb1.mrg = fnMarginRequired(MxSmb[i].smb1.name, MxSmb[i].smb1.lot);
         MxSmb[i].smb2.mrg = fnMarginRequired(MxSmb[i].smb2.name, MxSmb[i].smb2.lot);
         MxSmb[i].magic    = fnMagicGet(MxSmb, magic);
         if(MxSmb[i].magic <= 0) { Print("Sin magics libres"); break; }
         MxSmb[i].cmnt = cmnt + IntegerToString(MxSmb[i].magic) + " Open";

         if(MxSmb[i].PLBuy > MxSmb[i].spreadbuy && nnBuy && mmBuy)
         {
            MxSmb[i].smb3.mrg = fnMarginRequired(MxSmb[i].smb3.name, MxSmb[i].smb3.lotbuy);
            if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) > (MxSmb[i].smb1.mrg+MxSmb[i].smb2.mrg+MxSmb[i].smb3.mrg)*CF)
               fnOpen(MxSmb, i, true, openT);
         }
         else if(MxSmb[i].PLSell > MxSmb[i].spreadsell && nnSell && mmSell)
         {
            MxSmb[i].smb3.mrg = fnMarginRequired(MxSmb[i].smb3.name, MxSmb[i].smb3.lotsell);
            if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) > (MxSmb[i].smb1.mrg+MxSmb[i].smb2.mrg+MxSmb[i].smb3.mrg)*CF)
               fnOpen(MxSmb, i, false, openT);
         }
         if(MxSmb[i].status == 1)
            Print("Abriendo triángulo: "+MxSmb[i].smb1.name+"+"+MxSmb[i].smb2.name+"+"+MxSmb[i].smb3.name+" magic:"+IntegerToString(MxSmb[i].magic));
      }
   }
}

int fnMagicGet(stThree &MxSmb[], int magic)
{
   for(int m = magic; m < magic+MAGIC_RANGE; m++)
   {
      bool found = false;
      for(int p = PositionsTotal()-1; p >= 0; p--)
      {
         ulong t = PositionGetTicket(p);
         if(t > 0 && PositionSelectByTicket(t))
            if((int)PositionGetInteger(POSITION_MAGIC) == m) { found=true; break; }
      }
      if(!found) return m;
   }
   return 0;
}

bool fnOpen(stThree &MxSmb[], int i, bool side, ushort &opt)
{
   MxSmb[i].timeopen = TimeCurrent();
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))    return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))   return false;
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))     return false;

   MxSmb[i].smb1.tkt = MxSmb[i].smb2.tkt = MxSmb[i].smb3.tkt = 0;
   bool ok = false;

   if(side) // BUY
   {
      string s1=MxSmb[i].smb1.name, s2=MxSmb[i].smb2.name, s3=MxSmb[i].smb3.name;
      MxSmb[i].smb1.tkt = fnOrderSend(s1, ORDER_TYPE_BUY,  MxSmb[i].smb1.lot,
         NormalizeDouble(SymbolInfoDouble(s1,SYMBOL_ASK),(int)SymbolInfoInteger(s1,SYMBOL_DIGITS)), DEVIATION, MxSmb[i].cmnt, MxSmb[i].magic);
      if(MxSmb[i].smb1.tkt > 0)
      {
         MxSmb[i].status=1; opt++;
         MxSmb[i].smb2.tkt = fnOrderSend(s2, ORDER_TYPE_SELL, MxSmb[i].smb2.lot,
            NormalizeDouble(SymbolInfoDouble(s2,SYMBOL_BID),(int)SymbolInfoInteger(s2,SYMBOL_DIGITS)), DEVIATION, MxSmb[i].cmnt, MxSmb[i].magic);
         if(MxSmb[i].smb2.tkt > 0)
         {
            MxSmb[i].smb3.tkt = fnOrderSend(s3, ORDER_TYPE_SELL, MxSmb[i].smb3.lotsell,
               NormalizeDouble(SymbolInfoDouble(s3,SYMBOL_BID),(int)SymbolInfoInteger(s3,SYMBOL_DIGITS)), DEVIATION, MxSmb[i].cmnt, MxSmb[i].magic);
            if(MxSmb[i].smb3.tkt > 0) ok = true;
         }
         MxSmb[i].smb1.side=1; MxSmb[i].smb2.side=-1; MxSmb[i].smb3.side=-1;
      }
   }
   else // SELL
   {
      string s1=MxSmb[i].smb1.name, s2=MxSmb[i].smb2.name, s3=MxSmb[i].smb3.name;
      MxSmb[i].smb1.tkt = fnOrderSend(s1, ORDER_TYPE_SELL, MxSmb[i].smb1.lot,
         NormalizeDouble(SymbolInfoDouble(s1,SYMBOL_BID),(int)SymbolInfoInteger(s1,SYMBOL_DIGITS)), DEVIATION, MxSmb[i].cmnt, MxSmb[i].magic);
      if(MxSmb[i].smb1.tkt > 0)
      {
         MxSmb[i].status=1; opt++;
         MxSmb[i].smb2.tkt = fnOrderSend(s2, ORDER_TYPE_BUY,  MxSmb[i].smb2.lot,
            NormalizeDouble(SymbolInfoDouble(s2,SYMBOL_ASK),(int)SymbolInfoInteger(s2,SYMBOL_DIGITS)), DEVIATION, MxSmb[i].cmnt, MxSmb[i].magic);
         if(MxSmb[i].smb2.tkt > 0)
         {
            MxSmb[i].smb3.tkt = fnOrderSend(s3, ORDER_TYPE_BUY,  MxSmb[i].smb3.lotbuy,
               NormalizeDouble(SymbolInfoDouble(s3,SYMBOL_ASK),(int)SymbolInfoInteger(s3,SYMBOL_DIGITS)), DEVIATION, MxSmb[i].cmnt, MxSmb[i].magic);
            if(MxSmb[i].smb3.tkt > 0) ok = true;
         }
         MxSmb[i].smb1.side=-1; MxSmb[i].smb2.side=1; MxSmb[i].smb3.side=1;
      }
   }
   if(ok) { MxSmb[i].status=2; fnControlFile(MxSmb, i, g_fileLog); }
   return ok;
}

//===================================================================
// CIERRE DE TRIÁNGULOS
//===================================================================
void fnCalcPL(stThree &MxSmb[], double prft, int fh)
{
   bool flag = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
               AccountInfoInteger(ACCOUNT_TRADE_EXPERT)    &&
               AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)   &&
               TerminalInfoInteger(TERMINAL_CONNECTED);
   if(!flag) return;

   for(int i = ArraySize(MxSmb)-1; i >= 0; i--)
   {
      if(MxSmb[i].status <= 1) continue;
      if(MxSmb[i].status == 2)
      {
         MxSmb[i].pl = 0;
         ulong t1 = (ulong)MxSmb[i].smb1.tkt, t2 = (ulong)MxSmb[i].smb2.tkt, t3 = (ulong)MxSmb[i].smb3.tkt;
         if(fnPositionOpen(t1)) MxSmb[i].pl += fnPositionProfit(t1); else { MxSmb[i].status=3; fnCloseThree(MxSmb,i,fh); continue; }
         if(fnPositionOpen(t2)) MxSmb[i].pl += fnPositionProfit(t2); else { MxSmb[i].status=3; fnCloseThree(MxSmb,i,fh); continue; }
         if(fnPositionOpen(t3)) MxSmb[i].pl += fnPositionProfit(t3); else { MxSmb[i].status=3; fnCloseThree(MxSmb,i,fh); continue; }
         MxSmb[i].pl = NormalizeDouble(MxSmb[i].pl, 2);
         if(MxSmb[i].pl > prft && MxSmb[i].pl > 0) MxSmb[i].status = 3;
      }
      if(MxSmb[i].status == 3) fnCloseThree(MxSmb, i, fh);
   }
}

void fnCloseLeg(int &tkt, string smb, int digits)
{
   if(tkt <= 0) return;
   ulong t = (ulong)tkt;
   if(!fnPositionOpen(t)) { tkt = 0; return; }
   MqlTick tk;
   if(!SymbolInfoTick(smb, tk)) return;
   int    pt  = fnPositionType(t);
   double vol = fnPositionVolume(t);
   double closePrice = (pt == (int)POSITION_TYPE_BUY)
                       ? NormalizeDouble(tk.bid, digits)
                       : NormalizeDouble(tk.ask, digits);
   if(fnOrderClose(t, vol, closePrice, 100)) tkt = 0;
}

void fnCloseThree(stThree &MxSmb[], int i, int fh)
{
   if(!fnSmbCheck(MxSmb[i].smb1.name)) return;
   if(!fnSmbCheck(MxSmb[i].smb2.name)) return;
   if(!fnSmbCheck(MxSmb[i].smb3.name)) return;

   fnCloseLeg(MxSmb[i].smb1.tkt, MxSmb[i].smb1.name, MxSmb[i].smb1.digits);
   fnCloseLeg(MxSmb[i].smb2.tkt, MxSmb[i].smb2.name, MxSmb[i].smb2.digits);
   fnCloseLeg(MxSmb[i].smb3.tkt, MxSmb[i].smb3.name, MxSmb[i].smb3.digits);

   Print("Cierre: "+MxSmb[i].smb1.name+"+"+MxSmb[i].smb2.name+"+"+MxSmb[i].smb3.name+
         " P/L: "+DoubleToString(MxSmb[i].pl,2));

   if(MxSmb[i].smb1.tkt<=0 && MxSmb[i].smb2.tkt<=0 && MxSmb[i].smb3.tkt<=0)
   {
      fnControlFile(MxSmb, i, fh);
      fnUpdateAIScore(MxSmb, i);
      MxSmb[i].smb1.side=0; MxSmb[i].smb2.side=0; MxSmb[i].smb3.side=0;
      MxSmb[i].status=0;
      MxSmb[i].timeopen=TimeCurrent();
      if(fh != INVALID_HANDLE)
      {
         FileWrite(fh,"=== CLOSE ===");
         FileWrite(fh,"Symbols",MxSmb[i].smb1.name,MxSmb[i].smb2.name,MxSmb[i].smb3.name);
         FileWrite(fh,"Profit",DoubleToString(MxSmb[i].pl,3));
         FileWrite(fh,"Time",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
         FileFlush(fh);
      }
   }
}

//===================================================================
// RESTAURACIÓN TRAS REINICIO
//===================================================================
void fnRestart(stThree &MxSmb[], int magic)
{
   int posTotal = PositionsTotal();
   ulong    rTkt[];
   string   rSmb[];
   int      rMag[];
   datetime rTime[];
   ArrayResize(rTkt,  posTotal);
   ArrayResize(rSmb,  posTotal);
   ArrayResize(rMag,  posTotal);
   ArrayResize(rTime, posTotal);
   int cnt = 0;
   for(int i = 0; i < posTotal; i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      int mg = (int)PositionGetInteger(POSITION_MAGIC);
      if(mg < magic || mg > magic + MAGIC_RANGE) continue;
      rTkt[cnt]  = t;
      rSmb[cnt]  = PositionGetString(POSITION_SYMBOL);
      rMag[cnt]  = mg;
      rTime[cnt] = (datetime)PositionGetInteger(POSITION_TIME);
      cnt++;
   }
   uchar count = 0;
   for(int i = cnt-1; i >= 2; i--)
   for(int j = i-1;   j >= 1; j--)
   {
      if(rMag[j] != rMag[i]) continue;
      for(int k = j-1; k >= 0; k--)
      {
         if(rMag[k] != rMag[i]) continue;
         string s1 = rSmb[i], s2 = rSmb[j], s3 = rSmb[k];
         for(int m = ArraySize(MxSmb)-1; m >= 0; m--)
         {
            if(MxSmb[m].status != 0) continue;
            if((MxSmb[m].smb1.name==s1||MxSmb[m].smb1.name==s2||MxSmb[m].smb1.name==s3) &&
               (MxSmb[m].smb2.name==s1||MxSmb[m].smb2.name==s2||MxSmb[m].smb2.name==s3) &&
               (MxSmb[m].smb3.name==s1||MxSmb[m].smb3.name==s2||MxSmb[m].smb3.name==s3))
            {
               MxSmb[m].status   = 2;
               MxSmb[m].magic    = rMag[i];
               MxSmb[m].pl       = 0;
               MxSmb[m].timeopen = rTime[i];
               if(MxSmb[m].smb1.name==s1) MxSmb[m].smb1.tkt=(int)rTkt[i];
               if(MxSmb[m].smb1.name==s2) MxSmb[m].smb1.tkt=(int)rTkt[j];
               if(MxSmb[m].smb1.name==s3) MxSmb[m].smb1.tkt=(int)rTkt[k];
               if(MxSmb[m].smb2.name==s1) MxSmb[m].smb2.tkt=(int)rTkt[i];
               if(MxSmb[m].smb2.name==s2) MxSmb[m].smb2.tkt=(int)rTkt[j];
               if(MxSmb[m].smb2.name==s3) MxSmb[m].smb2.tkt=(int)rTkt[k];
               if(MxSmb[m].smb3.name==s1) MxSmb[m].smb3.tkt=(int)rTkt[i];
               if(MxSmb[m].smb3.name==s2) MxSmb[m].smb3.tkt=(int)rTkt[j];
               if(MxSmb[m].smb3.name==s3) MxSmb[m].smb3.tkt=(int)rTkt[k];
               count++; break;
            }
         }
      }
   }
   if(count > 0) Print("Restaurados "+IntegerToString(count)+" triangulos.");
}


//===================================================================
// ARCHIVO DE LOG
//===================================================================
void fnCreateFileSymbols(stThree &MxSmb[], int fh)
{
   FileWrite(fh,"Symbol1","Symbol2","Symbol3","Contract1","Contract2","Contract3",
               "LotMin1","LotMin2","LotMin3","LotMax1","LotMax2","LotMax3",
               "Digits1","Digits2","Digits3");
   for(int i = ArraySize(MxSmb)-1; i >= 0; i--)
      FileWrite(fh, MxSmb[i].smb1.name, MxSmb[i].smb2.name, MxSmb[i].smb3.name,
                    MxSmb[i].smb1.contract, MxSmb[i].smb2.contract, MxSmb[i].smb3.contract,
                    MxSmb[i].smb1.lot_min, MxSmb[i].smb2.lot_min, MxSmb[i].smb3.lot_min,
                    MxSmb[i].smb1.lot_max, MxSmb[i].smb2.lot_max, MxSmb[i].smb3.lot_max,
                    MxSmb[i].smb1.digits, MxSmb[i].smb2.digits, MxSmb[i].smb3.digits);
   FileWrite(fh,"");
   FileFlush(fh);
}

void fnControlFile(stThree &MxSmb[], int i, int fh)
{
   if(fh == INVALID_HANDLE) return;
   FileWrite(fh,"=== OPEN ===");
   FileWrite(fh,"Symbols", MxSmb[i].smb1.name, MxSmb[i].smb2.name, MxSmb[i].smb3.name);
   FileWrite(fh,"Tickets", MxSmb[i].smb1.tkt,  MxSmb[i].smb2.tkt,  MxSmb[i].smb3.tkt);
   FileWrite(fh,"PL_Buy",  DoubleToString(MxSmb[i].PLBuy,3));
   FileWrite(fh,"PL_Sell", DoubleToString(MxSmb[i].PLSell,3));
   FileWrite(fh,"Time",    TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   FileFlush(fh);
}

//===================================================================
//                    PANEL HUD PROFESIONAL
//===================================================================
// Helpers para crear/actualizar objetos gráficos

void ObjRect(string name, int x, int y, int w, int h, color clr, bool back=true)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     inPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      g_theme.border);
   ObjectSetInteger(0, name, OBJPROP_BACK,       back);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     false);
}

void ObjLabel(string name, int x, int y, string txt, color clr, int fsz, string font="Consolas", int anchor=ANCHOR_LEFT_UPPER)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    inPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString( 0, name, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fsz);
   ObjectSetString( 0, name, OBJPROP_FONT,      font);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,    anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    false);
}

void ObjDelete(string name) { ObjectDelete(0, name); }

void fnDeletePanel()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total-1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, g_pfx) == 0) ObjectDelete(0, nm);
   }
   ChartRedraw(0);
}

// Dibuja una fila label+valor con fondo opcional
//-------------------------------------------------------------------
// fnDrawPanel — Panel HUD compacto, columna unica, todo visible
//-------------------------------------------------------------------
void fnDrawPanel(stThree &MxSmb[], ushort openThree)
{
   if(!inPanelVisible) { fnDeletePanel(); return; }

   //--- Dimensiones base (ajustadas al ancho configurado)
   int total = ArraySize(MxSmb);
   int px    = inPanelX;
   int py    = inPanelY;
   int pw    = MathMax(280, inPanelWidth);  // minimo 280px
   int pad   = 8;
   int lh    = 15;   // line height uniforme
   int lv    = 55;   // columna de valores (offset desde px)
   // lv relativo al ancho: valores van alineados a la derecha del panel
   // Se usa ANCHOR_RIGHT_UPPER para los valores -> posicion = px+pw-pad

   //--- Calcular estadisticas
   double openPL=0, avgNN=0, avgScore=0, avgConf=0;
   uint   totTrades=0, totWins=0, totLosses=0;
   double bestEdge=-1e9; int bestIdx=-1;
   double topEdge[5]; int topIdx[5];
   for(int t=0;t<5;t++){topEdge[t]=-1e9; topIdx[t]=-1;}

   for(int i=0; i<total; i++)
   {
      if(MxSmb[i].status==2) openPL += MxSmb[i].pl;
      double eb = MxSmb[i].PLBuy  - MxSmb[i].spreadbuy;
      double es = MxSmb[i].PLSell - MxSmb[i].spreadsell;
      double e  = MathMax(eb,es);
      if(e > bestEdge){ bestEdge=e; bestIdx=i; }
      for(int t=0;t<5;t++)
         if(e > topEdge[t]){
            for(int q=4;q>t;q--){topEdge[q]=topEdge[q-1];topIdx[q]=topIdx[q-1];}
            topEdge[t]=e; topIdx[t]=i; break;
         }
      avgNN    += MxSmb[i].nnProb;
      avgScore += MxSmb[i].aiScore;
      avgConf  += MxSmb[i].aiConfidence;
      totTrades+= MxSmb[i].aiTrades;
      totWins  += MxSmb[i].aiWins;
      totLosses+= MxSmb[i].aiLosses;
   }
   if(total>0){avgNN/=total; avgScore/=total; avgConf/=total;}

   double winRate  = (totTrades>0) ? 100.0*totWins/totTrades : 0;
   double runtime  = (double)(TimeCurrent()-g_startTime)/3600.0;
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   color  plColor  = (g_totalProfit>=0) ? g_theme.green_hi : g_theme.red_hi;
   color  opColor  = (openPL>=0)        ? g_theme.green_hi : g_theme.red_hi;
   color  eqColor  = (equity>=balance)  ? g_theme.green_hi : g_theme.red_hi;
   color  wrColor  = (winRate>=55) ? g_theme.green_hi : (winRate>=45 ? g_theme.accent1 : g_theme.red_hi);
   color  scColor  = (avgScore>0)  ? g_theme.green_hi : (avgScore<-0.1 ? g_theme.red_hi : g_theme.accent1);
   color  nnPrColor= (avgNN>inNNBuyThr) ? g_theme.green_hi : (avgNN<inNNSellThr ? g_theme.red_hi : g_theme.accent1);

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   bool fridayLate = (dt.day_of_week==5 && dt.hour>=15);

   //--- Cursor vertical acumulado
   int cy = py;

   // Macro helper inline: dibuja fila etiqueta|valor en la columna unica
   // Etiqueta a la izquierda, valor alineado a la derecha del panel
   #define ROW_LV(tag, lbl, val, vc) \
      ObjLabel(g_pfx+(tag)+"_l", px+pad, cy, (lbl), g_theme.text_lo, 7, "Consolas"); \
      ObjLabel(g_pfx+(tag)+"_v", px+pw-pad, cy, (val), (vc), 7, "Consolas", ANCHOR_RIGHT_UPPER); \
      cy += lh;

   #define SEC_HDR(tag, ttl) \
      ObjRect(g_pfx+(tag)+"_hb", px, cy, pw, 2, g_theme.accent2); cy+=2; \
      ObjRect(g_pfx+(tag)+"_hg", px, cy, pw, 16, g_theme.bg_light); \
      ObjLabel(g_pfx+(tag)+"_ht", px+pad, cy+3, (ttl), g_theme.accent1, 8, "Consolas"); \
      cy += 17;

   //=== HEADER ===
   ObjRect(g_pfx+"hdr_top", px, cy, pw, 2, g_theme.accent1);   cy+=2;
   ObjRect(g_pfx+"hdr_bg",  px, cy, pw, 20, g_theme.bg_mid);
   ObjLabel(g_pfx+"hdr_ti", px+pad, cy+3, "ARB TRIANGULAR PRO v3.0", g_theme.accent1, 9, "Consolas");
   string stStr = fridayLate ? "PAUSADO" : "ACTIVO";
   color  stClr = fridayLate ? g_theme.red_hi : g_theme.green_hi;
   ObjLabel(g_pfx+"hdr_st", px+pw-pad, cy+3, stStr, stClr, 8, "Consolas", ANCHOR_RIGHT_UPPER);
   cy += 21;

   //=== BLOQUE P/L + CUENTA (4 filas) ===
   ObjRect(g_pfx+"bl1_bg", px, cy, pw, lh*4+pad*2, g_theme.bg_mid);
   cy += pad;
   ROW_LV("r01","P/L Sesion:", (g_totalProfit>=0?"+":"")+DoubleToString(g_totalProfit,2), plColor)
   ROW_LV("r02","P/L Abierto:", (openPL>=0?"+":"")+DoubleToString(openPL,2), opColor)
   ROW_LV("r03","Balance:", DoubleToString(balance,2), g_theme.text_hi)
   ROW_LV("r04","Equity:", DoubleToString(equity,2), eqColor)
   cy += pad;

   //=== BLOQUE TRIÁNGULOS + IA ===
   ObjRect(g_pfx+"bl2_bg", px, cy, pw, lh*5+pad*2, g_theme.bg_mid);
   cy += pad;
   ROW_LV("r05","Triangulos:", IntegerToString(openThree)+"/"+IntegerToString(total)+" abiertos/total", g_theme.accent1)
   ROW_LV("r06","Win Rate:", DoubleToString(winRate,1)+"%  (W:"+IntegerToString(totWins)+" L:"+IntegerToString(totLosses)+")", wrColor)
   ROW_LV("r07","IA Score:", DoubleToString(avgScore,3)+"  Conf:"+DoubleToString(avgConf,1)+"%", scColor)
   ROW_LV("r08","Margen libre:", DoubleToString(freeMargin,2), g_theme.text_hi)
   ROW_LV("r09","Runtime:", DoubleToString(runtime,1)+"h", g_theme.text_lo)
   cy += pad;

   //=== BLOQUE RED NEURONAL ===
   string nnSt = inUseNeuralNet ? (g_nnReady ? "ENTRENADA" : "PENDIENTE") : "OFF";
   color  nnCl = inUseNeuralNet ? (g_nnReady ? g_theme.green_hi : g_theme.accent2) : g_theme.text_lo;
   string trainStr = (g_nnLastTrain>0) ? TimeToString(g_nnLastTrain,TIME_MINUTES) : "N/A";
   ObjRect(g_pfx+"bl3_bg", px, cy, pw, lh*4+pad*2, g_theme.bg_mid);
   cy += pad;
   SEC_HDR("nn","NN  RED NEURONAL")
   ROW_LV("r10","Estado:", nnSt+"  TF:"+EnumToString(inNNTimeframe), nnCl)
   ROW_LV("r11","Precision:", DoubleToString(g_nnAccuracy*100,1)+"%  Loss:"+DoubleToString(g_nnLoss,4), g_theme.text_hi)
   ROW_LV("r12","Prob prom:", DoubleToString(avgNN*100,1)+"%  Muestras:"+DoubleToString(g_nnSamples,0), nnPrColor)
   ROW_LV("r13","Ult.Train:", trainStr, g_theme.text_lo)
   cy += pad;

   //=== MEJOR OPORTUNIDAD ===
   ObjRect(g_pfx+"bl4_bg", px, cy, pw, 2, g_theme.accent1); cy+=2;
   ObjRect(g_pfx+"bl4_hg", px, cy, pw, 16, g_theme.bg_light);
   ObjLabel(g_pfx+"bl4_ht", px+pad, cy+3, "MEJOR OPORTUNIDAD", g_theme.accent1, 8, "Consolas");
   cy+=17;
   ObjRect(g_pfx+"bl4_bd", px, cy, pw, lh*3+pad, g_theme.bg_mid);
   cy += 4;
   if(bestIdx >= 0)
   {
      double eb_b = MxSmb[bestIdx].PLBuy  - MxSmb[bestIdx].spreadbuy;
      double es_b = MxSmb[bestIdx].PLSell - MxSmb[bestIdx].spreadsell;
      bool   isBuy = (eb_b >= es_b);
      double edge  = MathMax(eb_b, es_b);
      string dirStr= isBuy ? "BUY" : "SELL";
      color  dirClr= isBuy ? g_theme.green_hi : g_theme.red_hi;
      color  edgClr= (edge>0) ? g_theme.green_hi : g_theme.red_hi;
      string symStr= MxSmb[bestIdx].smb1.name+"+"+MxSmb[bestIdx].smb2.name+"+"+MxSmb[bestIdx].smb3.name;
      ObjLabel(g_pfx+"b4_dir", px+pad, cy, dirStr, dirClr, 9, "Consolas"); cy+=lh;
      ObjLabel(g_pfx+"b4_sym", px+pad, cy, symStr, g_theme.text_hi, 7, "Consolas"); cy+=lh;
      string edgeTxt = "Edge:"+DoubleToString(edge,2)+"  NN:"+DoubleToString(MxSmb[bestIdx].nnProb*100,1)+"%  MM:"+(MxSmb[bestIdx].mmBias==1?"BUY":(MxSmb[bestIdx].mmBias==-1?"SELL":"FLAT"));
      ObjLabel(g_pfx+"b4_edg", px+pad, cy, edgeTxt, edgClr, 7, "Consolas"); cy+=lh;
      // barra edge
      int bMax = pw-pad*2;
      int bW   = MathMax(2,(int)(bMax*fnClamp(edge/10.0,0.0,1.0)));
      ObjRect(g_pfx+"b4_bbg", px+pad, cy, bMax, 5, g_theme.bg_light);
      ObjRect(g_pfx+"b4_bfg", px+pad, cy, bW,   5, edgClr);
      cy += 7;
   }
   else
   {
      ObjLabel(g_pfx+"b4_no", px+pad, cy, "Sin edge positivo disponible", g_theme.text_lo, 7, "Consolas");
      cy += lh*3;
   }
   cy += pad;

   //=== TOP 5 TABLA ===
   // Columnas: # | DIR | SIMBOLOS | EDGE | NN% | STAT
   // Anchos fijos relativos al panel
   int c0=px+pad;          // #
   int c1=px+pad+14;       // DIR
   int c2=px+pad+42;       // simbolos
   // valores del lado derecho con ANCHOR_RIGHT
   // EDGE a pw-90, NN a pw-45, STAT a pw-pad
   int cE=px+pw-90;
   int cN=px+pw-44;
   int cS=px+pw-pad;

   int topRows = 5;
   int topH    = 14 + (topRows+1)*(lh-1) + pad;
   ObjRect(g_pfx+"bl5_bg", px, cy, pw, 2, g_theme.accent2); cy+=2;
   ObjRect(g_pfx+"bl5_hg", px, cy, pw, 14, g_theme.bg_light);
   ObjLabel(g_pfx+"bl5_ht", px+pad, cy+2, "TOP 5 OPORTUNIDADES", g_theme.accent1, 8, "Consolas");
   cy+=14;
   ObjRect(g_pfx+"bl5_bd", px, cy, pw, (topRows+1)*(lh-1)+pad, g_theme.bg_mid);
   // cabecera columnas
   ObjLabel(g_pfx+"t5_h0", c0,  cy+2, "#",    g_theme.text_lo, 6, "Consolas");
   ObjLabel(g_pfx+"t5_h1", c1,  cy+2, "DIR",  g_theme.text_lo, 6, "Consolas");
   ObjLabel(g_pfx+"t5_h2", c2,  cy+2, "SIMBOLOS", g_theme.text_lo, 6, "Consolas");
   ObjLabel(g_pfx+"t5_h3", cE,  cy+2, "EDGE", g_theme.text_lo, 6, "Consolas", ANCHOR_RIGHT_UPPER);
   ObjLabel(g_pfx+"t5_h4", cN,  cy+2, "NN%",  g_theme.text_lo, 6, "Consolas", ANCHOR_RIGHT_UPPER);
   ObjLabel(g_pfx+"t5_h5", cS,  cy+2, "ST",   g_theme.text_lo, 6, "Consolas", ANCHOR_RIGHT_UPPER);
   cy += lh-1;

   for(int t=0; t<topRows; t++)
   {
      string rn = "r5_"+(string)t;
      color rowBg = (t%2==0) ? g_theme.bg_light : g_theme.bg_mid;
      ObjRect(g_pfx+rn+"_bg", px+1, cy, pw-2, lh-2, rowBg);
      int idx = topIdx[t];
      if(idx < 0)
      {
         ObjLabel(g_pfx+rn+"_e", c0, cy+1, IntegerToString(t+1)+"  ---", g_theme.text_lo, 6, "Consolas");
         cy += lh-1; continue;
      }
      double eb = MxSmb[idx].PLBuy  - MxSmb[idx].spreadbuy;
      double es = MxSmb[idx].PLSell - MxSmb[idx].spreadsell;
      bool   ib = (eb>=es);
      double e  = topEdge[t];
      color  dc = ib ? g_theme.green_hi : g_theme.red_hi;
      color  ec = (e>0) ? g_theme.green_hi : g_theme.red_hi;
      string st = (MxSmb[idx].status==0)?"LIB":(MxSmb[idx].status==1?"OPN":(MxSmb[idx].status==2?"ACT":"CLO"));
      color  stc= (MxSmb[idx].status==2) ? g_theme.green_hi : (MxSmb[idx].status==3 ? g_theme.red_hi : g_theme.accent2);
      string sym = MxSmb[idx].smb1.name+"+"+MxSmb[idx].smb2.name+"+"+MxSmb[idx].smb3.name;
      ObjLabel(g_pfx+rn+"_i",  c0, cy+1, IntegerToString(t+1), g_theme.text_lo, 6, "Consolas");
      ObjLabel(g_pfx+rn+"_d",  c1, cy+1, ib?"BUY":"SEL", dc,  6, "Consolas");
      ObjLabel(g_pfx+rn+"_s",  c2, cy+1, sym, g_theme.text_hi, 6, "Consolas");
      ObjLabel(g_pfx+rn+"_e2", cE, cy+1, DoubleToString(e,2), ec, 6, "Consolas", ANCHOR_RIGHT_UPPER);
      ObjLabel(g_pfx+rn+"_n",  cN, cy+1, DoubleToString(MxSmb[idx].nnProb*100,0), g_theme.text_hi, 6, "Consolas", ANCHOR_RIGHT_UPPER);
      ObjLabel(g_pfx+rn+"_t",  cS, cy+1, st, stc, 6, "Consolas", ANCHOR_RIGHT_UPPER);
      cy += lh-1;
   }
   cy += pad;

   //=== POSICIONES ABIERTAS ===
   int openCnt=0;
   for(int i=0;i<total;i++) if(MxSmb[i].status==2) openCnt++;
   int openH = 16 + MathMax(1,openCnt)*(lh-1) + pad;
   ObjRect(g_pfx+"bl6_ac", px, cy, 3, openH, g_theme.green_hi);
   ObjRect(g_pfx+"bl6_hg", px, cy, pw, 16, g_theme.bg_light);
   ObjLabel(g_pfx+"bl6_ht", px+pad+2, cy+3,
            "POSICIONES ABIERTAS ("+IntegerToString(openCnt)+")", g_theme.accent1, 8, "Consolas");
   cy+=16;
   ObjRect(g_pfx+"bl6_bd", px, cy, pw, MathMax(1,openCnt)*(lh-1)+pad, g_theme.bg_mid);

   if(openCnt==0)
   {
      ObjLabel(g_pfx+"op_no", px+pad+4, cy+3, "Sin posiciones abiertas", g_theme.text_lo, 7, "Consolas");
      cy += lh;
   }
   else
   {
      int oc=0;
      for(int i=total-1; i>=0; i--)
      {
         if(MxSmb[i].status!=2) continue;
         string rn="op_"+(string)oc;
         color rb=(oc%2==0)?g_theme.bg_light:g_theme.bg_mid;
         ObjRect(g_pfx+rn+"_bg", px+1, cy, pw-2, lh-2, rb);
         color pc=(MxSmb[i].pl>=0)?g_theme.green_hi:g_theme.red_hi;
         string plStr=(MxSmb[i].pl>=0?"+":"")+DoubleToString(MxSmb[i].pl,2);
         string sym2=MxSmb[i].smb1.name+"+"+MxSmb[i].smb2.name+"+"+MxSmb[i].smb3.name;
         string tStr=TimeToString(MxSmb[i].timeopen,TIME_MINUTES|TIME_SECONDS);
         ObjLabel(g_pfx+rn+"_s", px+pad+4, cy+1, sym2, g_theme.text_hi, 7, "Consolas");
         ObjLabel(g_pfx+rn+"_p", px+pw-pad-50, cy+1, plStr, pc, 7, "Consolas");
         ObjLabel(g_pfx+rn+"_t", px+pw-pad, cy+1, tStr, g_theme.text_lo, 6, "Consolas", ANCHOR_RIGHT_UPPER);
         cy+=lh-1; oc++;
      }
   }
   cy += pad;

   //=== FOOTER ===
   ObjRect(g_pfx+"ftr_bg", px, cy, pw, 18, g_theme.bg_dark);
   ObjRect(g_pfx+"ftr_ln", px, cy+16, pw, 2, g_theme.accent2);
   string timeStr = TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   ObjLabel(g_pfx+"ftr_ti", px+pad, cy+3, timeStr, g_theme.text_lo, 6, "Consolas");
   string accStr = AccountInfoString(ACCOUNT_SERVER)+" | "+(string)(int)AccountInfoInteger(ACCOUNT_LOGIN);
   ObjLabel(g_pfx+"ftr_ac", px+pw-pad, cy+3, accStr, g_theme.text_lo, 6, "Consolas", ANCHOR_RIGHT_UPPER);

   #undef ROW_LV
   #undef SEC_HDR

   ChartRedraw(0);
}


   int oy = cy + hSecHdr + 2;
   int maxShowOpen = (hOpenPos - hSecHdr - 6) / (lh+1);
   if(maxShowOpen < 1) maxShowOpen = 1;

   if(openCnt == 0)
   {
      ObjLabel(g_pfx+"pos_none", px+pad+4, oy+2, "Sin posiciones abiertas", g_theme.text_lo, 6, "Consolas");
   }
   else
   {
      int oc=0;
      for(int i=total-1; i>=0 && oc<maxShowOpen; i--)
      {
         if(MxSmb[i].status != 2) continue;
         string rn2 = IntegerToString(oc);
         color  rb2 = (oc%2==0)?g_theme.bg_light:g_theme.bg_mid;
         ObjRect(g_pfx+"pos_rbg"+rn2, px+pad, oy, pw-pad*2, lh, rb2);
         color pc2 = (MxSmb[i].pl>=0)?g_theme.green_hi:g_theme.red_hi;
         string plS2 = (MxSmb[i].pl>=0?"+":"")+DoubleToString(MxSmb[i].pl,2);
         string tmS  = TimeToString(MxSmb[i].timeopen, TIME_MINUTES|TIME_SECONDS);
         string symP = MxSmb[i].smb1.name+"+"+MxSmb[i].smb2.name+"+"+MxSmb[i].smb3.name;
         ObjLabel(g_pfx+"pos_sy"+rn2, px+pad+4,    oy+2, symP, g_theme.text_hi, 6, "Consolas");
         ObjLabel(g_pfx+"pos_pl"+rn2, px+pw-pad-50,oy+2, plS2, pc2, 6, "Consolas");
         ObjLabel(g_pfx+"pos_tm"+rn2, px+pw-pad,   oy+2, tmS,  g_theme.text_lo, 6, "Consolas", ANCHOR_RIGHT_UPPER);
         oy += lh+1; oc++;
      }
   }
   cy += hOpenPos + hSep;

   //=================================================================
   // FOOTER
   //=================================================================
   ObjRect(g_pfx+"ftr_bg",   px, cy, pw, hFooter, g_theme.bg_mid);
   ObjRect(g_pfx+"ftr_bot",  px, cy+hFooter-2, pw, 2, g_theme.accent2);
   ObjLabel(g_pfx+"ftr_time",px+pad, cy+4,
            TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            g_theme.text_lo, 6, "Consolas");
   ObjLabel(g_pfx+"ftr_acc", px+pw-pad, cy+4,
            AccountInfoString(ACCOUNT_SERVER)+" | "+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)),
            g_theme.text_lo, 6, "Consolas", ANCHOR_RIGHT_UPPER);

   ChartRedraw(0);
}


//===================================================================
// FIN DEL ARCHIVO
//===================================================================
