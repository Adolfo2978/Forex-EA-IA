//+------------------------------------------------------------------+
//|                                         DynamicRiskCalculator.mqh |
//|                      Forex Bot Pro v7.0 - Dynamic SL/TP Calculator |
//|                   Cálculo Inteligente de Stop Loss y Take Profit   |
//|                   Basado en ATR, Sesión, Fase MMM y Kill Zones    |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"
#include "MMMMethodology.mqh"

// DynamicRiskParams struct is defined in PositionManager.mqh to avoid duplication
// This class uses the shared DynamicRiskParams structure

class CDynamicRiskCalculator
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   CMMMMethodology* m_mmmAnalyzer;
   
   int m_atrHandle;
   int m_gmtOffset;
   
   // Base parameters
   double m_baseSLPips;      // 15 pips
   double m_baseTPPips;      // 45 pips
   double m_minSLPips;       // 12 pips
   double m_maxSLPips;       // 30 pips
   double m_minTPPips;       // 36 pips
   double m_maxTPPips;       // 90 pips
   double m_baseRiskRatio;   // 1:3 (45/15 = 3)
   
public:
   CDynamicRiskCalculator()
   {
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
      m_mmmAnalyzer = NULL;
      m_atrHandle = INVALID_HANDLE;
      m_gmtOffset = 0;
      
      m_baseSLPips = 15.0;
      m_baseTPPips = 45.0;
      m_minSLPips = 12.0;
      m_maxSLPips = 30.0;
      m_minTPPips = 36.0;
      m_maxTPPips = 90.0;
      m_baseRiskRatio = 3.0;
   }
   
   ~CDynamicRiskCalculator()
   {
      if(m_atrHandle != INVALID_HANDLE)
         IndicatorRelease(m_atrHandle);
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES tf, CMMMMethodology* mmmAnalyzer, int gmtOffset = 0)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_mmmAnalyzer = mmmAnalyzer;
      m_gmtOffset = gmtOffset;
      
      m_atrHandle = iATR(m_symbol, PERIOD_H1, 14);
      if(m_atrHandle == INVALID_HANDLE)
         Print("DynamicRiskCalc: Failed to create ATR handle for ", symbol);
   }
   
   void SetBaseParameters(double baseSL, double baseTP, double minSL, double maxSL)
   {
      m_baseSLPips = baseSL;
      m_baseTPPips = baseTP;
      m_minSLPips = minSL;
      m_maxSLPips = maxSL;
      m_baseRiskRatio = baseTP / baseSL;
   }
   
   // ========== MÉTODOS PRIVADOS DE CÁLCULO ==========
   
   double GetATRMultiplier()
   {
      if(m_atrHandle == INVALID_HANDLE) return 1.0;
      
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      
      if(CopyBuffer(m_atrHandle, 0, 0, 21, atrBuffer) < 21)
         return 1.0;
      
      double currentATR = atrBuffer[0];
      double avgATR = 0;
      for(int i = 1; i < 21; i++)
         avgATR += atrBuffer[i];
      avgATR /= 20;
      
      double atrRatio = currentATR / avgATR;
      
      // Si ATR > 150% del promedio, aumentar SL
      if(atrRatio > 1.5)
         return 1.2;  // SL +20%
      else if(atrRatio > 1.3)
         return 1.1;  // SL +10%
      else if(atrRatio < 0.8)
         return 0.9;  // SL -10%
      else if(atrRatio < 0.6)
         return 0.8;  // SL -20%
      
      return 1.0;  // Normal
   }
   
   double GetSessionMultiplier()
   {
      if(m_mmmAnalyzer == NULL)
         return 1.0;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = (dt.hour + m_gmtOffset) % 24;
      if(hour < 0) hour += 24;
      
      /*
         Asian Session: 0-8 GMT - Baja volatilidad
         London Session: 8-13 GMT - Alta volatilidad
         NY-London Overlap: 13-17 GMT - Volatilidad máxima
         New York Session: 17-22 GMT - Volatilidad alta
         Off-Hours: 22-0 GMT - Baja volatilidad
      */
      
      if(hour >= 0 && hour < 8)          // Asian
         return 0.9;    // SL -10% (menos volatilidad esperada)
      else if(hour >= 8 && hour < 13)    // London
         return 1.15;   // SL +15%
      else if(hour >= 13 && hour < 17)   // Overlap (máx volatilidad)
         return 1.30;   // SL +30%
      else if(hour >= 17 && hour < 22)   // New York
         return 1.20;   // SL +20%
      else                               // Off-hours
         return 0.85;   // SL -15%
      
      return 1.0;
   }
   
   double GetMMPhasMultiplier()
   {
      if(m_mmmAnalyzer == NULL)
         return 1.0;
      
      // Obtener fase actual del ciclo
      // NOTA: Necesita implementar GetCurrentCyclePhase en MMMMethodology
      // Por ahora retornamos multiplicador estándar
      
      /*
         Accumulation: Baja volatilidad esperada
         Markup: Volatilidad normal, momentum fuerte
         Distribution: Volatilidad alta, reversa próxima
         Markdown: Volatilidad máxima
      */
      
      return 1.0;  // Será actualizado cuando MMM esté disponible
   }
   
   double GetKillZoneMultiplier()
   {
      if(m_mmmAnalyzer == NULL)
         return 1.0;
      
      // Si estamos en Kill Zone válida de Market Maker
      // El riesgo es menor porque la probabilidad es mayor
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = (dt.hour + m_gmtOffset) % 24;
      if(hour < 0) hour += 24;
      int min = dt.min;
      
      // Kill zones típicas: 2-5, 8-11, 13-16
      bool inKillZone = false;
      if((hour >= 2 && hour < 5) ||
         (hour >= 8 && hour < 11) ||
         (hour >= 13 && hour < 16))
         inKillZone = true;
      
      if(inKillZone)
         return 0.8;    // SL -20% en Kill Zone válida
      
      return 1.0;
   }
   
   double GetImpulseStrengthMultiplier()
   {
      // Será implementado cuando NN proporcione impulse strength
      // Por ahora retornamos valor estándar
      return 1.0;
   }
   
   // ========== MÉTODO PRINCIPAL DE CÁLCULO ==========
   
   DynamicRiskParams CalculateRisk(bool isBuy, double entryPrice, double confidence = 75.0)
   {
      DynamicRiskParams result;
      ZeroMemory(result);
      
      // Obtener multiplicadores
      double atrMult = GetATRMultiplier();
      double sessionMult = GetSessionMultiplier();
      double phaseMult = GetMMPhasMultiplier();
      double killZoneMult = GetKillZoneMultiplier();
      double impulseMult = GetImpulseStrengthMultiplier();
      
      // Guardar en resultado para debugging
      result.atrMultiplier = atrMult;
      result.sessionMultiplier = sessionMult;
      result.phaseMultiplier = phaseMult;
      result.killZoneMultiplier = killZoneMult;
      result.impulseMultiplier = impulseMult;
      
      // Cálculo de SL final
      double finalSL = m_baseSLPips;
      finalSL *= atrMult;
      finalSL *= sessionMult;
      finalSL *= phaseMult;
      finalSL *= killZoneMult;
      
      // Limitar dentro de rango
      result.slPips = MathMax(m_minSLPips, MathMin(m_maxSLPips, finalSL));
      
      // Ajustar TP manteniendo Risk/Reward
      result.tpPips = result.slPips * m_baseRiskRatio * impulseMult;
      result.tpPips = MathMax(m_minTPPips, MathMin(m_maxTPPips, result.tpPips));
      
      // Recalcular ratio final
      result.finalRiskRatio = result.tpPips / result.slPips;
      
      // Convertir a precios
      CSymbolInfo si;
      si.Name(m_symbol);
      si.RefreshRates();
      
      double pipValue = GetPipValue();
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      double slDistance = result.slPips * pipValue;
      double tpDistance = result.tpPips * pipValue;
      
      if(isBuy)
      {
         result.slPrice = NormalizeDouble(entryPrice - slDistance, digits);
         result.tpPrice = NormalizeDouble(entryPrice + tpDistance, digits);
      }
      else
      {
         result.slPrice = NormalizeDouble(entryPrice + slDistance, digits);
         result.tpPrice = NormalizeDouble(entryPrice - tpDistance, digits);
      }
      
      // Crear debug info
      result.debugInfo = StringFormat("ATR:%.2f|Session:%.2f|Phase:%.2f|KZ:%.2f|Impulse:%.2f",
                                     atrMult, sessionMult, phaseMult, killZoneMult, impulseMult);
      
      return result;
   }
   
   // ========== MÉTODOS AUXILIARES ==========
   
   double GetPipValue()
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      if(digits == 3 || digits == 5)
         return point * 10;
      return point;
   }
   
   // Validar que el Risk/Reward sea acceptable
   bool ValidateRiskRatio(double slPips, double tpPips, double minRatio = 1.0)
   {
      if(slPips <= 0) return false;
      double ratio = tpPips / slPips;
      return ratio >= minRatio;
   }
   
   // Aplicar ajuste de confianza a los SL/TP
   void ApplyConfidenceAdjustment(DynamicRiskParams& params, double confidence)
   {
      if(confidence > 80)
      {
         params.slPips *= 0.95;  // Reducir SL 5% si muy confiado
         params.tpPips *= 1.05;  // Aumentar TP 5%
      }
      else if(confidence < 70)
      {
         params.slPips *= 1.05;  // Aumentar SL 5% si poco confiado
         params.tpPips *= 0.95;  // Reducir TP 5%
      }
      
      // Re-aplicar límites
      params.slPips = MathMax(m_minSLPips, MathMin(m_maxSLPips, params.slPips));
      params.tpPips = MathMax(m_minTPPips, MathMin(m_maxTPPips, params.tpPips));
   }
   
   // Obtener análisis de SL/TP
   void PrintAnalysis(const DynamicRiskParams& params)
   {
      Print("=== DYNAMIC RISK ANALYSIS ===");
      Print("Base SL: ", DoubleToString(m_baseSLPips, 1), " pips");
      Print("Base TP: ", DoubleToString(m_baseTPPips, 1), " pips");
      Print("Final SL: ", DoubleToString(params.slPips, 1), " pips");
      Print("Final TP: ", DoubleToString(params.tpPips, 1), " pips");
      Print("Risk/Reward: 1:", DoubleToString(params.finalRiskRatio, 2));
      Print("Multipliers: ", params.debugInfo);
      Print("============================");
   }
};
