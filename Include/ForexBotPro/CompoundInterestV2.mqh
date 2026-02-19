//+------------------------------------------------------------------+
//|                                        CompoundInterestV2.mqh   |
//|                                                                  |
//|        INTELLIGENT COMPOUND INTEREST & SMART POSITION SCALING   |
//|                    ForexBotPro v7.1+ Enhancement               |
//|                                                                  |
//|  Sistema Inteligente de Interés Compuesto:                     |
//|  • Escalado automático de lotes cada 10% de ganancia            |
//|  • Hasta 3 trades activos simultáneamente                       |
//|  • Búsqueda activa de oportunidades múltiples                   |
//|  • Tracking de capital en tiempo real                           |
//|  • Persistencia de datos (recuperación ante reinicio)           |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "ForexBotPro Development Team"
#property version   "2.0"
#property strict

#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+

struct SCompoundState
{
   double initialCapital;          // Capital inicial ($)
   double currentCapital;          // Capital actual (actualizado en tiempo real)
   double peakCapital;             // Máximo capital alcanzado
   double totalProfit;             // Ganancia total acumulada
   int totalTrades;                // Total de trades ejecutados
   int winningTrades;              // Trades ganadores
   double profitFactor;            // Profit factor (ganancias / pérdidas)
   double returnOnEquity;          // ROE = ganancias / capital inicial
   datetime lastUpdateTime;        // Última actualización
};

struct SLotScaling
{
   double baseLot;                 // Lote base inicial
   double currentLot;              // Lote actual
   int scalingLevel;               // Nivel actual de escalado (0-10)
   double profitThreshold;         // Umbral de ganancia para próximo escalado
   double lastScalingProfit;       // Ganancia en último escalado
   datetime scalingUpdateTime;     // Cuándo se escaló por última vez
};

struct STradeOpportunity
{
   string symbol;                  // Símbolo
   ENUM_SIGNAL_TYPE signal;        // BUY/SELL
   double confidence;              // Confianza 0-100
   double iaScore;                 // Score IA
   double technicalScore;          // Score técnico
   datetime analysisTime;          // Cuándo se analizó
   int priority;                   // Prioridad 1-3 (1=máx)
   bool isMultiplierOK;           // ¿Cumple con factor multiplicador?
};

//+------------------------------------------------------------------+
//| CLASS: CCompoundInterestV2                                      |
//+------------------------------------------------------------------+

class CCompoundInterestV2
{
private:
   CPositionInfo m_position;
   
   // Estado de capital
   SCompoundState m_state;
   SLotScaling m_scaling;
   
   // Parámetros
   double m_initialCapital;
   double m_baseLot;
   double m_compoundThreshold;     // 10% para escalar
   double m_maxDailyProfit;        // Meta diaria
   double m_minDailyProfit;        // Mínimo para escalar
   bool m_compoundEnabled;
   
   // Límites de trading
   int m_maxPositionsPerDay;       // Máximo 3 trades por día
   int m_currentDayTrades;         // Trades realizados hoy
   int m_lastTradingDay;           // Día del último trade
   
   // Tracking de oportunidades
   STradeOpportunity m_dailyOpportunities[];
   int m_opportunityCount;
   
   // Persistencia
   string m_persistenceFile;
   
public:
   CCompoundInterestV2() 
   { 
      Initialize();
   }
   
   ~CCompoundInterestV2() 
   { 
      SaveState();
   }
   
   //────────────────────────────────────────────────────────────────
   // INICIALIZACIÓN
   //────────────────────────────────────────────────────────────────
   
   void Initialize()
   {
      m_state.initialCapital = 1000.0;
      m_state.currentCapital = 1000.0;
      m_state.peakCapital = 1000.0;
      m_state.totalProfit = 0.0;
      m_state.totalTrades = 0;
      m_state.winningTrades = 0;
      m_state.profitFactor = 0.0;
      m_state.returnOnEquity = 0.0;
      m_state.lastUpdateTime = TimeCurrent();
      
      m_scaling.baseLot = 0.01;
      m_scaling.currentLot = 0.01;
      m_scaling.scalingLevel = 0;
      m_scaling.profitThreshold = 100.0; // $100 = 10%
      m_scaling.lastScalingProfit = 0.0;
      m_scaling.scalingUpdateTime = TimeCurrent();
      
      m_compoundEnabled = true;
      m_compoundThreshold = 0.10; // 10%
      m_maxDailyProfit = 500.0;   // $500 máximo por día
      m_minDailyProfit = 50.0;    // $50 mínimo para escalar
      m_maxPositionsPerDay = 3;   // 3 trades máximo
      m_currentDayTrades = 0;
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      m_lastTradingDay = dt.day;
      
      m_opportunityCount = 0;
      m_persistenceFile = "ForexBotPro_CompoundState.bin";
      
      LoadState();
   }
   
   void SetInitialCapital(double capital)
   {
      m_initialCapital = capital;
      m_state.initialCapital = capital;
      m_state.currentCapital = capital;
      m_state.peakCapital = capital;
      
      // Calcular threshold de compounding (10%)
      m_scaling.profitThreshold = capital * m_compoundThreshold;
   }
   
   void SetBaseLot(double lot)
   {
      m_baseLot = lot;
      m_scaling.baseLot = lot;
      m_scaling.currentLot = lot;
   }
   
   void SetCompoundEnabled(bool enabled)
   {
      m_compoundEnabled = enabled;
   }
   
   //────────────────────────────────────────────────────────────────
   // MONITOREO DE CAPITAL EN TIEMPO REAL
   //────────────────────────────────────────────────────────────────
   
   void UpdateCapitalFromAccount()
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Calcular ganancia actual
      double currentProfit = accountEquity - accountBalance;
      double previousCapital = m_state.currentCapital;
      
      m_state.currentCapital = accountEquity;
      
      // Actualizar pico de capital
      if(accountEquity > m_state.peakCapital)
      {
         m_state.peakCapital = accountEquity;
      }
      
      // Actualizar ganancias totales
      m_state.totalProfit = accountEquity - m_state.initialCapital;
      m_state.returnOnEquity = (m_state.totalProfit / m_state.initialCapital) * 100;
      
      m_state.lastUpdateTime = TimeCurrent();
      
      // Verificar si debemos escalar
      if(m_compoundEnabled)
      {
         CheckAndApplyCompounding(previousCapital);
      }
   }
   
   //────────────────────────────────────────────────────────────────
   // ESCALADO INTELIGENTE DE LOTES (COMPOUND INTEREST)
   //────────────────────────────────────────────────────────────────
   
   void CheckAndApplyCompounding(double previousCapital)
   {
      double profitSinceLastScaling = m_state.currentCapital - m_scaling.lastScalingProfit;
      
      // Verificar si alcanzamos el 10% de ganancia
      if(profitSinceLastScaling >= m_scaling.profitThreshold)
      {
         ApplyLotScaling();
      }
   }
   
   void ApplyLotScaling()
   {
      int newScalingLevel = m_scaling.scalingLevel + 1;
      
      // Limitar a nivel 10 (máximo 10x el lote base)
      if(newScalingLevel > 10)
         newScalingLevel = 10;
      
      double newLot = m_baseLot * newScalingLevel;
      
      // Validar que el lote no exceda límite de servidor
      if(newLot > 100.0)
         newLot = 100.0;
      
      // Validar que sea múltiplo de 0.01
      newLot = MathRound(newLot / 0.01) * 0.01;
      
      // Aplicar nuevo lote
      m_scaling.lastScalingProfit = m_state.currentCapital;
      m_scaling.currentLot = newLot;
      m_scaling.scalingLevel = newScalingLevel;
      m_scaling.scalingUpdateTime = TimeCurrent();
      
      // Log
      PrintFormat("[COMPOUND] ✓ Lot Scaling Applied: Level %d | New Lot: %.2f | Capital: $%.2f",
         newScalingLevel, newLot, m_state.currentCapital);
      
      SaveState();
   }
   
   double GetCurrentLot()
   {
      return m_scaling.currentLot;
   }
   
   //────────────────────────────────────────────────────────────────
   // GESTIÓN DE 3 TRADES POR DÍA
   //────────────────────────────────────────────────────────────────
   
   bool CanOpenNewTrade()
   {
      // Verificar si es nuevo día
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day != m_lastTradingDay)
      {
         m_currentDayTrades = 0;
         m_lastTradingDay = dt.day;
      }
      
      // Verificar límite de 3 trades por día
      if(m_currentDayTrades >= m_maxPositionsPerDay)
      {
         return false;
      }
      
      // Verificar si ya tenemos máximo de posiciones abiertas
      int openPositions = CountOpenPositions();
      if(openPositions >= m_maxPositionsPerDay)
      {
         return false;
      }
      
      return true;
   }
   
   void RegisterNewTrade(string symbol, ENUM_SIGNAL_TYPE signal, double confidence)
   {
      m_currentDayTrades++;
      
      PrintFormat("[COMPOUND] Trade #%d/3 opened: %s %s (Confidence: %.1f%%)",
         m_currentDayTrades, symbol, 
         signal == SIGNAL_BUY ? "BUY" : "SELL",
         confidence);
   }
   
   int CountOpenPositions()
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() == 123456) // Ajustar al magic number
               count++;
         }
      }
      return count;
   }
   
   int GetRemainingTradesForDay()
   {
      return m_maxPositionsPerDay - m_currentDayTrades;
   }
   
   int GetCurrentDayTradeCount()
   {
      return m_currentDayTrades;
   }
   
   //────────────────────────────────────────────────────────────────
   // BÚSQUEDA ACTIVA DE OPORTUNIDADES MÚLTIPLES
   //────────────────────────────────────────────────────────────────
   
   void AddOpportunity(string symbol, ENUM_SIGNAL_TYPE signal, double confidence, 
                       double iaScore, double technicalScore)
   {
      if(m_opportunityCount >= 10) // Máximo 10 oportunidades almacenadas
         return;
      
      m_dailyOpportunities[m_opportunityCount].symbol = symbol;
      m_dailyOpportunities[m_opportunityCount].signal = signal;
      m_dailyOpportunities[m_opportunityCount].confidence = confidence;
      m_dailyOpportunities[m_opportunityCount].iaScore = iaScore;
      m_dailyOpportunities[m_opportunityCount].technicalScore = technicalScore;
      m_dailyOpportunities[m_opportunityCount].analysisTime = TimeCurrent();
      m_dailyOpportunities[m_opportunityCount].priority = CalculatePriority(confidence, iaScore);
      m_dailyOpportunities[m_opportunityCount].isMultiplierOK = true;
      
      m_opportunityCount++;
      
      // Ordenar por prioridad
      SortOpportunitiesByPriority();
   }
   
   STradeOpportunity GetNextOpportunity()
   {
      STradeOpportunity empty;
      ZeroMemory(empty);
      
      if(m_opportunityCount == 0)
         return empty;
      
      // Retornar la oportunidad de más alta prioridad
      return m_dailyOpportunities[0];
   }
   
   void ClearOpportunities()
   {
      m_opportunityCount = 0;
      ArrayResize(m_dailyOpportunities, 0);
   }
   
   int GetOpportunityCount()
   {
      return m_opportunityCount;
   }
   
   //────────────────────────────────────────────────────────────────
   // ESTADÍSTICAS Y REPORTES
   //────────────────────────────────────────────────────────────────
   
   void PrintCompoundingStatus()
   {
      Print("═════════════════════════════════════════════════════════");
      Print("COMPOUND INTEREST & POSITION SCALING STATUS");
      Print("═════════════════════════════════════════════════════════");
      
      // Capital
      PrintFormat("Initial Capital:      $%.2f", m_state.initialCapital);
      PrintFormat("Current Capital:      $%.2f", m_state.currentCapital);
      PrintFormat("Peak Capital:         $%.2f", m_state.peakCapital);
      PrintFormat("Total Profit:         $%.2f (+%.2f%%)", 
         m_state.totalProfit, m_state.returnOnEquity);
      
      // Lot Scaling
      PrintFormat("\nLot Scaling:");
      PrintFormat("Base Lot:             %.2f", m_scaling.baseLot);
      PrintFormat("Current Lot:          %.2f (Level %d/10)", 
         m_scaling.currentLot, m_scaling.scalingLevel);
      PrintFormat("Profit for Next Scale: $%.2f / $%.2f (%.1f%%)",
         m_state.currentCapital - m_scaling.lastScalingProfit,
         m_scaling.profitThreshold,
         ((m_state.currentCapital - m_scaling.lastScalingProfit) / m_scaling.profitThreshold) * 100);
      
      // Daily Trading
      PrintFormat("\nDaily Trading (Max 3/day):");
      PrintFormat("Trades Today:         %d/3", m_currentDayTrades);
      PrintFormat("Remaining Trades:     %d", GetRemainingTradesForDay());
      PrintFormat("Open Positions:       %d", CountOpenPositions());
      
      // Opportunities
      PrintFormat("\nActive Opportunities:");
      PrintFormat("Total Found:          %d", m_opportunityCount);
      if(m_opportunityCount > 0)
      {
         PrintFormat("  1st Priority: %s (Conf: %.1f%%)", 
            m_dailyOpportunities[0].symbol,
            m_dailyOpportunities[0].confidence);
         if(m_opportunityCount > 1)
            PrintFormat("  2nd Priority: %s (Conf: %.1f%%)", 
               m_dailyOpportunities[1].symbol,
               m_dailyOpportunities[1].confidence);
         if(m_opportunityCount > 2)
            PrintFormat("  3rd Priority: %s (Conf: %.1f%%)", 
               m_dailyOpportunities[2].symbol,
               m_dailyOpportunities[2].confidence);
      }
      
      // Statistics
      PrintFormat("\nStatistics:");
      PrintFormat("Total Trades:         %d", m_state.totalTrades);
      PrintFormat("Winning Trades:       %d (%.1f%%)", 
         m_state.winningTrades,
         m_state.totalTrades > 0 ? (m_state.winningTrades * 100.0 / m_state.totalTrades) : 0);
      PrintFormat("Last Update:          %s", TimeToString(m_state.lastUpdateTime));
      
      Print("═════════════════════════════════════════════════════════");
   }
   
   //────────────────────────────────────────────────────────────────
   // GETTERS
   //────────────────────────────────────────────────────────────────
   
   double GetCurrentCapital() { return m_state.currentCapital; }
   double GetInitialCapital() { return m_state.initialCapital; }
   double GetPeakCapital() { return m_state.peakCapital; }
   double GetTotalProfit() { return m_state.totalProfit; }
   double GetReturnOnEquity() { return m_state.returnOnEquity; }
   int GetScalingLevel() { return m_scaling.scalingLevel; }
   double GetProfitThreshold() { return m_scaling.profitThreshold; }
   double GetProfitUntilNextScale()
   {
      return m_state.currentCapital - m_scaling.lastScalingProfit;
   }
   double GetPercentageToNextScale()
   {
      double profit = GetProfitUntilNextScale();
      if(m_scaling.profitThreshold <= 0) return 0;
      return (profit / m_scaling.profitThreshold) * 100.0;
   }
   
   //────────────────────────────────────────────────────────────────
   // PRIVADOS - FUNCIONES AUXILIARES
   //────────────────────────────────────────────────────────────────
   
private:
   
   int CalculatePriority(double confidence, double iaScore)
   {
      // Escala de 1-3, donde 1 es máxima prioridad
      double combinedScore = (confidence + iaScore) / 2.0;
      
      if(combinedScore >= 80.0)
         return 1; // Alta prioridad
      else if(combinedScore >= 70.0)
         return 2; // Media prioridad
      else
         return 3; // Baja prioridad
   }
   
   void SortOpportunitiesByPriority()
   {
      // Ordenamiento de burbujas simple
      for(int i = 0; i < m_opportunityCount - 1; i++)
      {
         for(int j = 0; j < m_opportunityCount - i - 1; j++)
         {
            if(m_dailyOpportunities[j].priority > m_dailyOpportunities[j+1].priority)
            {
               STradeOpportunity temp = m_dailyOpportunities[j];
               m_dailyOpportunities[j] = m_dailyOpportunities[j+1];
               m_dailyOpportunities[j+1] = temp;
            }
         }
      }
   }
   
   //────────────────────────────────────────────────────────────────
   // PERSISTENCIA (Guardado/Carga de Estado)
   //────────────────────────────────────────────────────────────────
   
   void SaveState()
   {
      int handle = FileOpen(m_persistenceFile, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         Print("[COMPOUND] Warning: Could not save state to file");
         return;
      }
      
      // Escribir estado
      FileWriteDouble(handle, m_state.initialCapital);
      FileWriteDouble(handle, m_state.currentCapital);
      FileWriteDouble(handle, m_state.peakCapital);
      FileWriteDouble(handle, m_state.totalProfit);
      FileWriteInteger(handle, m_state.totalTrades);
      FileWriteInteger(handle, m_state.winningTrades);
      
      // Escribir scaling
      FileWriteDouble(handle, m_scaling.baseLot);
      FileWriteDouble(handle, m_scaling.currentLot);
      FileWriteInteger(handle, m_scaling.scalingLevel);
      FileWriteDouble(handle, m_scaling.lastScalingProfit);
      
      FileClose(handle);
   }
   
   void LoadState()
   {
      int handle = FileOpen(m_persistenceFile, FILE_READ | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         Print("[COMPOUND] Info: No previous state file found. Starting fresh.");
         return;
      }
      
      // Leer estado
      m_state.initialCapital = FileReadDouble(handle);
      m_state.currentCapital = FileReadDouble(handle);
      m_state.peakCapital = FileReadDouble(handle);
      m_state.totalProfit = FileReadDouble(handle);
      m_state.totalTrades = FileReadInteger(handle);
      m_state.winningTrades = FileReadInteger(handle);
      
      // Leer scaling
      m_scaling.baseLot = FileReadDouble(handle);
      m_scaling.currentLot = FileReadDouble(handle);
      m_scaling.scalingLevel = FileReadInteger(handle);
      m_scaling.lastScalingProfit = FileReadDouble(handle);
      
      FileClose(handle);
      
      Print("[COMPOUND] State restored from file. Current capital: $", 
            DoubleToString(m_state.currentCapital, 2));
   }
};

//+------------------------------------------------------------------+
// END OF CompoundInterestV2.mqh
//+------------------------------------------------------------------+
