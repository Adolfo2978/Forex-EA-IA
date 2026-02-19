//+------------------------------------------------------------------+
//|                                            PositionManager.mqh  |
//|                              Forex Bot Pro v7.0 - Position Mgmt  |
//|                              Trailing Stop, Compound Interest    |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include "Enums.mqh"

struct PositionMonitorData
{
   ulong ticket;
   string symbol;
   ENUM_POSITION_TYPE posType;
   double lastIAScore;
   double lastTechScore;
   double lastAlignScore;
   double entryIAScore;
   double entryTechScore;
   double entryAlignScore;
   datetime lastUpdateTime;
   datetime entryTime;
   int consecutiveMisalignments;
   int consecutiveScoreDrops;
   bool isAlignedM15;
   bool isAlignedM30;
   bool isAlignedH1;
   double dynamicSLPips;
   double dynamicTPPips;
   double entryPrice;
   bool breakevenApplied;
   double peakCombinedScore;
};

struct DynamicRiskParams
{
   double slPips;
   double tpPips;
   double slPrice;
   double tpPrice;
   double atrValue;
   double sessionMultiplier;
   double levelMultiplier;
   double cycleMultiplier;
   double atrMultiplier;
   double phaseMultiplier;
   double killZoneMultiplier;
   double impulseMultiplier;
   double finalRiskRatio;
   string debugInfo;
};

class CPositionManager
{
private:
   CTrade m_trade;
   CPositionInfo m_position;
   CSymbolInfo m_symbol;
   
   ulong m_magicNumber;
   double m_trailingActivationPips;
   double m_trailingStopPips;
   double m_trailingStepPips;
   double m_stopLossPips;
   double m_takeProfitPips;
   double m_breakEvenActivationPips;
   bool m_trailingEnabled;
   bool m_profitProtectionEnabled;
   bool m_mtfMonitorEnabled;
   bool m_closeLossOnMTFMisalign;
   int m_maxMisalignmentCount;
   
   bool m_dynamicDurationEnabled;
   double m_minHoldScore;
   bool m_closeOnScoreDrop;
   int m_scoreDropBars;
   bool m_useMMCycleExit;
   double m_iaWeight;
   double m_techWeight;
   double m_alignWeight;
   
   bool m_dynamicSLEnabled;
   double m_atrMultiplier;
   double m_minSLPips;
   double m_maxSLPips;
   double m_rrRatio;
   double m_breakevenTriggerMultiplier;
   double m_breakevenBufferPips;
   
   int m_atrHandles[];
   
   double m_lastDynamicSLPips;
   double m_lastDynamicTPPips;
   double m_lastEntryPrice;
   
   double m_initialCapital;
   double m_currentCapital;
   double m_baseLot;
   double m_currentLot;
   bool m_compoundEnabled;
   
   int m_totalTrades;
   int m_winningTrades;
   double m_totalProfit;
   double m_totalPips;
   
   PositionMonitorData m_monitors[];
   int m_monitorCount;
   
public:
   CPositionManager()
   {
      m_magicNumber = 123456;
      m_trailingActivationPips = 200;
      m_trailingStopPips = 100;
      m_trailingStepPips = 50;
      m_stopLossPips = 250;
      m_takeProfitPips = 500;
      m_breakEvenActivationPips = 150;
      m_trailingEnabled = true;
      m_profitProtectionEnabled = false;
      m_mtfMonitorEnabled = true;
      m_closeLossOnMTFMisalign = false;
      m_maxMisalignmentCount = 8;
      
      m_dynamicDurationEnabled = false;
      m_minHoldScore = 30.0;
      m_closeOnScoreDrop = false;
      m_scoreDropBars = 5;
      m_useMMCycleExit = false;
      m_iaWeight = 0.35;
      m_techWeight = 0.35;
      m_alignWeight = 0.30;
      
      m_dynamicSLEnabled = true;
      m_atrMultiplier = 1.5;
      m_minSLPips = 15;
      m_maxSLPips = 100;
      m_rrRatio = 3.0;
      m_breakevenTriggerMultiplier = 2.0;
      m_breakevenBufferPips = 2.0;
      
      ArrayResize(m_atrHandles, 0);
      
      m_lastDynamicSLPips = 0;
      m_lastDynamicTPPips = 0;
      m_lastEntryPrice = 0;
      
      m_initialCapital = 10.0;
      m_currentCapital = 10.0;
      m_baseLot = 0.01;
      m_currentLot = 0.01;
      m_compoundEnabled = true;
      
      m_totalTrades = 0;
      m_winningTrades = 0;
      m_totalProfit = 0;
      m_totalPips = 0;
      
      ArrayResize(m_monitors, 0);
      m_monitorCount = 0;
   }
   
   void Init(ulong magic, double slPips, double tpPips, double trailingActivation, 
             double trailingStop, double trailingStep, double initialCap, double baseLot)
   {
      m_magicNumber = magic;
      m_stopLossPips = slPips;
      m_takeProfitPips = tpPips;
      m_trailingActivationPips = trailingActivation;
      m_trailingStopPips = trailingStop;
      m_trailingStepPips = trailingStep;
      m_initialCapital = initialCap;
      m_currentCapital = initialCap;
      m_baseLot = baseLot;
      m_currentLot = baseLot;
      
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(20);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   }
   
   void SetTrailingEnabled(bool enabled) { m_trailingEnabled = enabled; }
   void SetProfitProtection(bool enabled) { m_profitProtectionEnabled = enabled; }
   void SetBreakEvenActivation(double pips) { m_breakEvenActivationPips = pips; }
   void SetCompoundEnabled(bool enabled) { m_compoundEnabled = enabled; }
   void SetMTFMonitorEnabled(bool enabled) { m_mtfMonitorEnabled = enabled; }
   void SetCloseLossOnMTFMisalign(bool enabled) { m_closeLossOnMTFMisalign = enabled; }
   void SetMaxMisalignmentCount(int count) { m_maxMisalignmentCount = count; }
   
   void SetDynamicDuration(bool enabled, double minScore, bool closeOnDrop, int dropBars, bool useMMExit)
   {
      m_dynamicDurationEnabled = enabled;
      m_minHoldScore = minScore;
      m_closeOnScoreDrop = closeOnDrop;
      m_scoreDropBars = dropBars;
      m_useMMCycleExit = useMMExit;
   }
   
   void SetScoreWeights(double ia, double tech, double align)
   {
      m_iaWeight = ia;
      m_techWeight = tech;
      m_alignWeight = align;
   }
   
   void SetDynamicSLEnabled(bool enabled) { m_dynamicSLEnabled = enabled; }
   void SetATRMultiplier(double mult) { m_atrMultiplier = mult; }
   void SetMinMaxSLPips(double minPips, double maxPips) { m_minSLPips = minPips; m_maxSLPips = maxPips; }
   void SetRRRatio(double ratio) { m_rrRatio = ratio; }
   void SetBreakevenParams(double triggerMult, double bufferPips) 
   { 
      m_breakevenTriggerMultiplier = triggerMult; 
      m_breakevenBufferPips = bufferPips; 
   }
   
   double GetLastDynamicSL() { return m_lastDynamicSLPips; }
   double GetLastDynamicTP() { return m_lastDynamicTPPips; }
   double GetLastEntryPrice() { return m_lastEntryPrice; }
   
   int SimpleStringHash(string s)
   {
      int hash = 0;
      int len = StringLen(s);
      for(int i = 0; i < len; i++)
         hash = 31 * hash + StringGetCharacter(s, i);
      return hash;
   }
   
   int GetOrCreateATRHandle(string symbol)
   {
      int symbolHash = SimpleStringHash(symbol);
      
      for(int i = 0; i < ArraySize(m_atrHandles); i += 2)
      {
         if(i + 1 < ArraySize(m_atrHandles) && m_atrHandles[i] == symbolHash)
            return m_atrHandles[i + 1];
      }
      
      int handle = iATR(symbol, PERIOD_H1, 14);
      int size = ArraySize(m_atrHandles);
      ArrayResize(m_atrHandles, size + 2);
      m_atrHandles[size] = symbolHash;
      m_atrHandles[size + 1] = handle;
      return handle;
   }
   
   DynamicRiskParams CalculateDynamicRisk(string symbol, bool isBuy, 
                                           int killZone, int beeKayLevel, int dayCycle)
   {
      DynamicRiskParams params;
      ZeroMemory(params);
      
      m_symbol.Name(symbol);
      m_symbol.RefreshRates();
      
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double pipValue = GetPipValue(symbol);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      int atrHandle = GetOrCreateATRHandle(symbol);
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      
      if(CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) < 3)
      {
         params.slPips = m_stopLossPips;
         params.tpPips = m_takeProfitPips;
         return params;
      }
      
      double atrPips = atrBuffer[0] / pipValue;
      params.atrValue = atrBuffer[0];
      
      switch(killZone)
      {
         case 1: params.sessionMultiplier = 0.7; break;
         case 2: params.sessionMultiplier = 1.0; break;
         case 3: params.sessionMultiplier = 1.1; break;
         case 4: params.sessionMultiplier = 0.9; break;
         default: params.sessionMultiplier = 0.8; break;
      }
      
      switch(beeKayLevel)
      {
         case 1: params.levelMultiplier = 1.1; break;
         case 2: params.levelMultiplier = 1.2; break;
         case 3: params.levelMultiplier = 0.7; break;
         default: params.levelMultiplier = 1.0; break;
      }
      
      switch(dayCycle)
      {
         case 1: params.cycleMultiplier = 0.8; break;
         case 2: params.cycleMultiplier = 1.0; break;
         case 3: params.cycleMultiplier = 0.6; break;
         default: params.cycleMultiplier = 0.9; break;
      }
      
      double baseSL = atrPips * m_atrMultiplier;
      double adjustedSL = baseSL * params.sessionMultiplier * params.levelMultiplier * params.cycleMultiplier;
      
      params.slPips = MathMax(m_minSLPips, MathMin(m_maxSLPips, adjustedSL));
      params.tpPips = params.slPips * m_rrRatio;
      
      double slDistance = params.slPips * pipValue;
      double tpDistance = params.tpPips * pipValue;
      
      double price = isBuy ? m_symbol.Ask() : m_symbol.Bid();
      
      if(isBuy)
      {
         params.slPrice = NormalizeDouble(price - slDistance, digits);
         params.tpPrice = NormalizeDouble(price + tpDistance, digits);
      }
      else
      {
         params.slPrice = NormalizeDouble(price + slDistance, digits);
         params.tpPrice = NormalizeDouble(price - tpDistance, digits);
      }
      
      Print(">>> Dynamic Risk: ATR=", DoubleToString(atrPips, 1), "p | Session=", 
            DoubleToString(params.sessionMultiplier, 1), " | Level=", DoubleToString(params.levelMultiplier, 1),
            " | Cycle=", DoubleToString(params.cycleMultiplier, 1));
      Print(">>> SL=", DoubleToString(params.slPips, 1), "p | TP=", DoubleToString(params.tpPips, 1), 
            "p (1:", DoubleToString(m_rrRatio, 0), ")");
      
      return params;
   }
   
   double CalculateScaledLot(int entryLevel)
   {
      double scalingFactors[] = {5.0, 4.0, 3.0, 2.0, 1.0};
      double totalRatio = 15.0;
      
      if(entryLevel < 0 || entryLevel > 4) entryLevel = 0;
      
      double lotMultiplier = scalingFactors[entryLevel] / totalRatio;
      double scaledLot = m_currentLot * lotMultiplier * 5.0;
      
      return MathMax(0.01, MathMin(scaledLot, 10.0));
   }
   
   ulong OpenScaledPosition(string symbol, ENUM_SIGNAL_TYPE signal, double confidence, int entryLevel)
   {
      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL &&
         signal != SIGNAL_STRONG_BUY && signal != SIGNAL_STRONG_SELL &&
         signal != SIGNAL_CONFIRMED_BUY && signal != SIGNAL_CONFIRMED_SELL)
         return 0;
      
      m_symbol.Name(symbol);
      m_symbol.RefreshRates();
      
      double pipValue = GetPipValue(symbol);
      double slDistance = m_stopLossPips * pipValue;
      double tpDistance = m_takeProfitPips * pipValue;
      
      double scaledLot = CalculateScaledLot(entryLevel);
      
      bool isBuy = (signal == SIGNAL_BUY || signal == SIGNAL_STRONG_BUY || 
                    signal == SIGNAL_CONFIRMED_BUY || signal == SIGNAL_WEAK_BUY ||
                    signal == SIGNAL_MODERATE_BUY);
      
      double price, sl, tp;
      ENUM_ORDER_TYPE orderType;
      
      if(isBuy)
      {
         price = m_symbol.Ask();
         sl = price - slDistance;
         tp = price + tpDistance;
         orderType = ORDER_TYPE_BUY;
      }
      else
      {
         price = m_symbol.Bid();
         sl = price + slDistance;
         tp = price - tpDistance;
         orderType = ORDER_TYPE_SELL;
      }
      
      string comment = StringFormat("FBP_L%d_%.0f", entryLevel+1, confidence);
      
      if(m_trade.PositionOpen(symbol, orderType, scaledLot, price, sl, tp, comment))
      {
         Sleep(100);
         
         ulong positionTicket = 0;
         
         if(PositionSelect(symbol))
            positionTicket = PositionGetInteger(POSITION_TICKET);
         
         if(positionTicket == 0)
         {
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               if(m_position.SelectByIndex(i) && 
                  m_position.Magic() == m_magicNumber && 
                  m_position.Symbol() == symbol)
               {
                  positionTicket = m_position.Ticket();
                  break;
               }
            }
         }
         
         Print("Scaled Position L", entryLevel+1, " opened: ", symbol, " ", (isBuy ? "BUY" : "SELL"), 
               " Lot: ", scaledLot, " (", DoubleToString(CalculateScaledLot(entryLevel)/m_currentLot*100, 0), "%)");
         return positionTicket;
      }
      
      return 0;
   }
   
   void MoveToBreakEven(ulong ticket, double minProfitPips = 20)
   {
      if(!PositionSelectByTicket(ticket)) return;
      if(m_position.Magic() != m_magicNumber) return;
      
      string symbol = m_position.Symbol();
      m_symbol.Name(symbol);
      m_symbol.RefreshRates();
      
      double pipValue = GetPipValue(symbol);
      double openPrice = m_position.PriceOpen();
      double currentSL = m_position.StopLoss();
      double currentTP = m_position.TakeProfit();
      
      double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                            m_symbol.Bid() : m_symbol.Ask();
      
      double profitPips = (currentPrice - openPrice) / pipValue;
      if(m_position.PositionType() == POSITION_TYPE_SELL)
         profitPips = -profitPips;
      
      if(profitPips >= minProfitPips)
      {
         double beSpread = 2 * pipValue;
         double newSL;
         
         if(m_position.PositionType() == POSITION_TYPE_BUY)
         {
            newSL = openPrice + beSpread;
            if(newSL > currentSL)
            {
               if(m_trade.PositionModify(ticket, newSL, currentTP))
                  Print("Moved to Break-Even: ", symbol, " SL=", newSL);
            }
         }
         else
         {
            newSL = openPrice - beSpread;
            if(newSL < currentSL || currentSL == 0)
            {
               if(m_trade.PositionModify(ticket, newSL, currentTP))
                  Print("Moved to Break-Even: ", symbol, " SL=", newSL);
            }
         }
      }
   }
   
   double GetPipValue(string symbol)
   {
      m_symbol.Name(symbol);
      double point = m_symbol.Point();
      int digits = m_symbol.Digits();
      
      if(digits == 3 || digits == 5)
         return point * 10;
      return point;
   }
   
   void UpdateLotSize()
   {
      if(!m_compoundEnabled)
      {
         m_currentLot = m_baseLot;
         return;
      }
      
      int multiplier = 1;
      double threshold = m_initialCapital;
      
      while(m_currentCapital >= threshold * 2)
      {
         multiplier *= 2;
         threshold *= 2;
      }
      
      m_currentLot = m_baseLot * multiplier;
      m_currentLot = MathMax(0.01, MathMin(m_currentLot, 10.0));
   }
   
   double GetCurrentLot() { return m_currentLot; }
   double GetCurrentCapital() { return m_currentCapital; }
   int GetMultiplier() 
   { 
      int mult = 1;
      double thresh = m_initialCapital;
      while(m_currentCapital >= thresh * 2) { mult *= 2; thresh *= 2; }
      return mult;
   }
   
   void UpdateCapital(double profit)
   {
      m_currentCapital += profit;
      UpdateLotSize();
   }
   
   ulong OpenPosition(string symbol, ENUM_SIGNAL_TYPE signal, double confidence,
                      int killZone = 0, int beeKayLevel = 0, int dayCycle = 0, double patternTargetPrice = 0.0,
                      double slMultiplier = 1.0)
   {
      if(signal != SIGNAL_BUY && signal != SIGNAL_SELL &&
         signal != SIGNAL_STRONG_BUY && signal != SIGNAL_STRONG_SELL &&
         signal != SIGNAL_CONFIRMED_BUY && signal != SIGNAL_CONFIRMED_SELL)
         return 0;
      
      m_symbol.Name(symbol);
      m_symbol.RefreshRates();
      
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double pipValue = GetPipValue(symbol);
      
      bool isBuy = (signal == SIGNAL_BUY || signal == SIGNAL_STRONG_BUY || 
                    signal == SIGNAL_CONFIRMED_BUY || signal == SIGNAL_WEAK_BUY ||
                    signal == SIGNAL_MODERATE_BUY);
      
      double slPipsUsed, tpPipsUsed;
      double price, sl, tp;
      ENUM_ORDER_TYPE orderType;
      
      if(m_dynamicSLEnabled && (killZone > 0 || beeKayLevel > 0 || dayCycle > 0))
      {
         DynamicRiskParams riskParams = CalculateDynamicRisk(symbol, isBuy, killZone, beeKayLevel, dayCycle);
         slPipsUsed = riskParams.slPips;
         tpPipsUsed = riskParams.tpPips;
      }
      else
      {
         slPipsUsed = m_stopLossPips;
         tpPipsUsed = m_takeProfitPips;
      }
      
      if(slMultiplier <= 0)
         slMultiplier = 1.0;
      
      slMultiplier = MathMax(0.6, MathMin(1.0, slMultiplier));
      slPipsUsed = slPipsUsed * slMultiplier;
      slPipsUsed = MathMax(m_minSLPips, MathMin(m_maxSLPips, slPipsUsed));
      tpPipsUsed = slPipsUsed * m_rrRatio;
      
      double slDistance = slPipsUsed * pipValue;
      double tpDistance = tpPipsUsed * pipValue;
      
      if(isBuy)
      {
         sl = NormalizeDouble(m_symbol.Ask() - slDistance, digits);
         tp = NormalizeDouble(m_symbol.Ask() + tpDistance, digits);
      }
      else
      {
         sl = NormalizeDouble(m_symbol.Bid() + slDistance, digits);
         tp = NormalizeDouble(m_symbol.Bid() - tpDistance, digits);
      }
      
      if(patternTargetPrice > 0.0 && pipValue > 0.0)
      {
         double minTargetPips = MathMax(8.0, slPipsUsed * 1.2);
         if(isBuy && patternTargetPrice > m_symbol.Ask())
         {
            double targetPips = (patternTargetPrice - m_symbol.Ask()) / pipValue;
            if(targetPips >= minTargetPips && targetPips < tpPipsUsed)
            {
               tpPipsUsed = targetPips;
               tp = NormalizeDouble(patternTargetPrice, digits);
            }
         }
         else if(!isBuy && patternTargetPrice < m_symbol.Bid())
         {
            double targetPips = (m_symbol.Bid() - patternTargetPrice) / pipValue;
            if(targetPips >= minTargetPips && targetPips < tpPipsUsed)
            {
               tpPipsUsed = targetPips;
               tp = NormalizeDouble(patternTargetPrice, digits);
            }
         }
      }
      
      UpdateLotSize();
      
      if(isBuy)
      {
         price = NormalizeDouble(m_symbol.Ask(), digits);
         orderType = ORDER_TYPE_BUY;
      }
      else
      {
         price = NormalizeDouble(m_symbol.Bid(), digits);
         orderType = ORDER_TYPE_SELL;
      }
      
      m_lastDynamicSLPips = slPipsUsed;
      m_lastDynamicTPPips = tpPipsUsed;
      m_lastEntryPrice = price;
      
      Print(">>> Opening ", (isBuy ? "BUY" : "SELL"), " ", symbol, 
            " Price: ", DoubleToString(price, digits),
            " SL: ", DoubleToString(sl, digits), " (", DoubleToString(slPipsUsed, 1), " pips)",
            " TP: ", DoubleToString(tp, digits), " (", DoubleToString(tpPipsUsed, 1), " pips) [1:", 
            DoubleToString(m_rrRatio, 0), "]");
      
      string comment = StringFormat("FBP_%.0f", confidence);
      
      if(m_trade.PositionOpen(symbol, orderType, m_currentLot, price, sl, tp, comment))
      {
         Sleep(100);
         
         ulong positionTicket = 0;
         
         if(PositionSelect(symbol))
         {
            positionTicket = PositionGetInteger(POSITION_TICKET);
         }
         
         if(positionTicket == 0)
         {
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               if(m_position.SelectByIndex(i) && 
                  m_position.Magic() == m_magicNumber && 
                  m_position.Symbol() == symbol)
               {
                  positionTicket = m_position.Ticket();
                  break;
               }
            }
         }
         
         if(positionTicket == 0)
         {
            ulong dealTicket = m_trade.ResultDeal();
            if(HistoryDealSelect(dealTicket))
               positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         }
         
         if(positionTicket > 0 && m_position.SelectByTicket(positionTicket))
         {
            double actualSL = m_position.StopLoss();
            double actualTP = m_position.TakeProfit();
            
            if(actualSL == 0 || actualTP == 0)
            {
               Print(">>> WARNING: SL/TP not set! Attempting modification...");
               Print(">>> Actual SL: ", actualSL, " Actual TP: ", actualTP);
               
               if(m_trade.PositionModify(positionTicket, sl, tp))
               {
                  Print(">>> SL/TP modification successful");
               }
               else
               {
                  Print(">>> SL/TP modification failed: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
               }
            }
            else
            {
               Print(">>> Position opened with SL: ", DoubleToString(actualSL, digits), 
                     " TP: ", DoubleToString(actualTP, digits));
            }
         }
         
         Print("Position opened: ", symbol, " ", (isBuy ? "BUY" : "SELL"), 
               " PositionTicket: ", positionTicket, 
               " Lot: ", m_currentLot, " Confidence: ", confidence);
         return positionTicket;
      }
      else
      {
         Print("Error opening position: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
         return 0;
      }
   }
   
   void ManagePositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != m_magicNumber) continue;
         
         string symbol = m_position.Symbol();
         m_symbol.Name(symbol);
         m_symbol.RefreshRates();
         
         ulong ticket = m_position.Ticket();
         double pipValue = GetPipValue(symbol);
         double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                               m_symbol.Bid() : m_symbol.Ask();
         double openPrice = m_position.PriceOpen();
         
         double currentSL = m_position.StopLoss();
         double currentTP = m_position.TakeProfit();
         
         if(currentSL == 0 || currentTP == 0)
         {
            EnsureStopLossSet(symbol, openPrice, pipValue);
            continue;
         }
         
         double profitPips = (currentPrice - openPrice) / pipValue;
         if(m_position.PositionType() == POSITION_TYPE_SELL)
            profitPips = -profitPips;
         
         int monitorIdx = FindMonitorIndex(ticket);
         if(monitorIdx >= 0)
         {
            double dynamicSL = m_monitors[monitorIdx].dynamicSLPips;
            double breakevenTrigger = dynamicSL * m_breakevenTriggerMultiplier;
            
            if(!m_monitors[monitorIdx].breakevenApplied && profitPips >= breakevenTrigger)
            {
               ApplyDynamicBreakeven(ticket, openPrice, pipValue, profitPips, dynamicSL);
               m_monitors[monitorIdx].breakevenApplied = true;
            }
         }
         
         if(m_trailingEnabled && (monitorIdx < 0 || m_monitors[monitorIdx].breakevenApplied))
            ApplyTrailingStop(profitPips, pipValue);
         
         if(m_profitProtectionEnabled && profitPips > 0)
            ApplyProfitProtection();
         
         CheckCloseConditions(profitPips);
      }
   }
   
   void ApplyDynamicBreakeven(ulong ticket, double openPrice, double pipValue, double profitPips, double dynamicSL)
   {
      int digits = (int)SymbolInfoInteger(m_position.Symbol(), SYMBOL_DIGITS);
      double bufferDistance = m_breakevenBufferPips * pipValue;
      double newSL;
      double currentTP = m_position.TakeProfit();
      
      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         newSL = NormalizeDouble(openPrice + bufferDistance, digits);
      }
      else
      {
         newSL = NormalizeDouble(openPrice - bufferDistance, digits);
      }
      
      if(m_trade.PositionModify(ticket, newSL, currentTP))
      {
         Print(">>> BREAKEVEN aplicado a ", DoubleToString(profitPips, 1), " pips (trigger: ", 
               DoubleToString(dynamicSL * m_breakevenTriggerMultiplier, 1), " pips = 2x SL)");
         Print(">>> Nuevo SL: ", DoubleToString(newSL, digits), " (entry + ", 
               DoubleToString(m_breakevenBufferPips, 1), " pips buffer) | TP intacto: ", 
               DoubleToString(currentTP, digits));
      }
      else
      {
         Print(">>> Error aplicando breakeven: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
      }
   }
   
   void EnsureStopLossSet(string symbol, double openPrice, double pipValue)
   {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double slDistance = m_stopLossPips * pipValue;
      double tpDistance = m_takeProfitPips * pipValue;
      
      double sl, tp;
      ulong ticket = m_position.Ticket();
      
      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         sl = NormalizeDouble(openPrice - slDistance, digits);
         tp = NormalizeDouble(openPrice + tpDistance, digits);
      }
      else
      {
         sl = NormalizeDouble(openPrice + slDistance, digits);
         tp = NormalizeDouble(openPrice - tpDistance, digits);
      }
      
      Print(">>> Fixing missing SL/TP for ticket ", ticket, " SL: ", DoubleToString(sl, digits), 
            " TP: ", DoubleToString(tp, digits));
      
      if(m_trade.PositionModify(ticket, sl, tp))
      {
         Print(">>> SL/TP set successfully for ticket ", ticket);
      }
      else
      {
         Print(">>> Failed to set SL/TP: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
      }
   }
   
   void ApplyTrailingStop(double profitPips, double pipValue)
   {
      if(profitPips < m_trailingActivationPips) return;
      
      double trailingDistance = m_trailingStopPips * pipValue;
      double stepDistance = m_trailingStepPips * pipValue;
      
      m_symbol.Name(m_position.Symbol());
      m_symbol.RefreshRates();
      
      double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                            m_symbol.Bid() : m_symbol.Ask();
      double currentSL = m_position.StopLoss();
      double newSL;
      
      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         newSL = currentPrice - trailingDistance;
         if(newSL > currentSL + stepDistance)
         {
            m_trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
            Print("Trailing Stop updated: ", m_position.Symbol(), " New SL: ", newSL);
         }
      }
      else
      {
         newSL = currentPrice + trailingDistance;
         if(newSL < currentSL - stepDistance || currentSL == 0)
         {
            m_trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
            Print("Trailing Stop updated: ", m_position.Symbol(), " New SL: ", newSL);
         }
      }
   }
   
   void ApplyProfitProtection()
   {
      string symbol = m_position.Symbol();
      m_symbol.Name(symbol);
      m_symbol.RefreshRates();
      
      double openPrice = m_position.PriceOpen();
      double currentSL = m_position.StopLoss();
      double pipValue = GetPipValue(symbol);
      
      double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                            m_symbol.Bid() : m_symbol.Ask();
      
      double profitPips = (currentPrice - openPrice) / pipValue;
      if(m_position.PositionType() == POSITION_TYPE_SELL)
         profitPips = -profitPips;
      
      if(profitPips < m_breakEvenActivationPips)
         return;
      
      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         if(currentSL < openPrice)
         {
            m_trade.PositionModify(m_position.Ticket(), openPrice, m_position.TakeProfit());
            Print("Breakeven applied at ", DoubleToString(profitPips, 1), " pips: ", symbol);
         }
      }
      else
      {
         if(currentSL > openPrice || currentSL == 0)
         {
            m_trade.PositionModify(m_position.Ticket(), openPrice, m_position.TakeProfit());
            Print("Breakeven applied at ", DoubleToString(profitPips, 1), " pips: ", symbol);
         }
      }
   }
   
   void CheckCloseConditions(double profitPips)
   {
   }
   
   void RegisterPositionMonitor(ulong ticket, string symbol, ENUM_POSITION_TYPE posType,
                                 double iaScore, double techScore, double alignScore,
                                 double dynamicSL = 0, double dynamicTP = 0, double entryPrice = 0)
   {
      if(ticket == 0)
      {
         Print("WARNING: RegisterPositionMonitor called with ticket=0 for ", symbol, " - skipping");
         return;
      }
      
      int idx = FindMonitorIndex(ticket);
      if(idx >= 0)
      {
         m_monitors[idx].lastIAScore = iaScore;
         m_monitors[idx].lastTechScore = techScore;
         m_monitors[idx].lastAlignScore = alignScore;
         m_monitors[idx].lastUpdateTime = TimeCurrent();
         return;
      }
      
      int size = ArraySize(m_monitors);
      ArrayResize(m_monitors, size + 1);
      m_monitors[size].ticket = ticket;
      m_monitors[size].symbol = symbol;
      m_monitors[size].posType = posType;
      m_monitors[size].lastIAScore = iaScore;
      m_monitors[size].lastTechScore = techScore;
      m_monitors[size].lastAlignScore = alignScore;
      m_monitors[size].entryIAScore = iaScore;
      m_monitors[size].entryTechScore = techScore;
      m_monitors[size].entryAlignScore = alignScore;
      m_monitors[size].lastUpdateTime = TimeCurrent();
      m_monitors[size].entryTime = TimeCurrent();
      m_monitors[size].consecutiveMisalignments = 0;
      m_monitors[size].consecutiveScoreDrops = 0;
      m_monitors[size].isAlignedM15 = true;
      m_monitors[size].isAlignedM30 = true;
      m_monitors[size].isAlignedH1 = true;
      m_monitors[size].dynamicSLPips = (dynamicSL > 0) ? dynamicSL : m_stopLossPips;
      m_monitors[size].dynamicTPPips = (dynamicTP > 0) ? dynamicTP : m_takeProfitPips;
      m_monitors[size].entryPrice = entryPrice;
      m_monitors[size].breakevenApplied = false;
      double entryCombo = (iaScore * m_iaWeight) + (techScore * m_techWeight) + (alignScore * m_alignWeight);
      m_monitors[size].peakCombinedScore = entryCombo;
      m_monitorCount++;
      
      Print(">>> Monitor registered: SL=", DoubleToString(m_monitors[size].dynamicSLPips, 1), 
            "p | TP=", DoubleToString(m_monitors[size].dynamicTPPips, 1), 
            "p | Entry=", DoubleToString(entryPrice, 5),
            " | Breakeven trigger at: ", DoubleToString(m_monitors[size].dynamicSLPips * m_breakevenTriggerMultiplier, 1), " pips");
   }
   
   int FindMonitorIndex(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_monitors); i++)
      {
         if(m_monitors[i].ticket == ticket)
            return i;
      }
      return -1;
   }
   
   void RemoveMonitor(ulong ticket)
   {
      int idx = FindMonitorIndex(ticket);
      if(idx < 0) return;
      
      int size = ArraySize(m_monitors);
      for(int i = idx; i < size - 1; i++)
         m_monitors[i] = m_monitors[i + 1];
      
      ArrayResize(m_monitors, size - 1);
      m_monitorCount--;
   }
   
   bool CheckMTFAlignmentForPosition(string symbol, ENUM_POSITION_TYPE posType,
                                      bool &alignM15, bool &alignM30, bool &alignH1)
   {
      double ema50[], ema200[];
      bool isBuy = (posType == POSITION_TYPE_BUY);
      
      alignM15 = CheckEMAAlignmentTF(symbol, PERIOD_M15, isBuy);
      alignM30 = CheckEMAAlignmentTF(symbol, PERIOD_M30, isBuy);
      alignH1 = CheckEMAAlignmentTF(symbol, PERIOD_H1, isBuy);
      
      int alignedCount = (alignM15 ? 1 : 0) + (alignM30 ? 1 : 0) + (alignH1 ? 1 : 0);
      return (alignedCount >= 2);
   }
   
   bool CheckEMAAlignmentTF(string symbol, ENUM_TIMEFRAMES tf, bool isBuy)
   {
      int ema50Handle = iMA(symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
      int ema200Handle = iMA(symbol, tf, 200, 0, MODE_EMA, PRICE_CLOSE);
      
      if(ema50Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE)
         return true;
      
      double ema50Val[], ema200Val[];
      ArraySetAsSeries(ema50Val, true);
      ArraySetAsSeries(ema200Val, true);
      
      if(CopyBuffer(ema50Handle, 0, 0, 1, ema50Val) <= 0) return true;
      if(CopyBuffer(ema200Handle, 0, 0, 1, ema200Val) <= 0) return true;
      
      IndicatorRelease(ema50Handle);
      IndicatorRelease(ema200Handle);
      
      if(isBuy)
         return (ema50Val[0] > ema200Val[0]);
      else
         return (ema50Val[0] < ema200Val[0]);
   }
   
   void UpdatePositionMonitors(double &iaScore, double &techScore, double &alignScore,
                                bool newDataAvailable)
   {
      if(!m_mtfMonitorEnabled) return;
      
      for(int i = ArraySize(m_monitors) - 1; i >= 0; i--)
      {
         ulong ticket = m_monitors[i].ticket;
         
         if(!m_position.SelectByTicket(ticket))
         {
            RemoveMonitor(ticket);
            continue;
         }
         
         string symbol = m_monitors[i].symbol;
         ENUM_POSITION_TYPE posType = m_monitors[i].posType;
         
         bool alignM15, alignM30, alignH1;
         bool isAligned = CheckMTFAlignmentForPosition(symbol, posType, alignM15, alignM30, alignH1);
         
         m_monitors[i].isAlignedM15 = alignM15;
         m_monitors[i].isAlignedM30 = alignM30;
         m_monitors[i].isAlignedH1 = alignH1;
         
         if(newDataAvailable)
         {
            m_monitors[i].lastIAScore = iaScore;
            m_monitors[i].lastTechScore = techScore;
            m_monitors[i].lastAlignScore = alignScore;
            m_monitors[i].lastUpdateTime = TimeCurrent();
         }
         
         if(!isAligned)
         {
            m_monitors[i].consecutiveMisalignments++;
            Print("MTF Misalignment #", m_monitors[i].consecutiveMisalignments, 
                  " for ", symbol, " [M15:", alignM15, " M30:", alignM30, " H1:", alignH1, "]");
            
            if(m_monitors[i].consecutiveMisalignments >= m_maxMisalignmentCount)
            {
               double profit = m_position.Profit();
               if(profit > 0 && m_closeLossOnMTFMisalign)
               {
                  Print("Closing ", symbol, " due to MTF misalignment - protecting profit");
                  ClosePosition(ticket, "MTF misalignment - profit protected");
               }
               else
               {
                  Print("Position ", symbol, " misaligned (", m_monitors[i].consecutiveMisalignments, "x) - ",
                        "waiting for SL/TP");
                  m_monitors[i].consecutiveMisalignments = m_maxMisalignmentCount;
               }
            }
         }
         else
         {
            if(m_monitors[i].consecutiveMisalignments > 0)
            {
               Print("MTF Realigned for ", symbol);
               m_monitors[i].consecutiveMisalignments = 0;
            }
         }
      }
   }
   
   void GetPositionMonitorStatus(ulong ticket, string &status)
   {
      int idx = FindMonitorIndex(ticket);
      if(idx < 0)
      {
         status = "Not monitored";
         return;
      }
      
      status = StringFormat("IA:%.0f%% Tech:%.0f%% Align:%.0f%% [M15:%s M30:%s H1:%s]",
                            m_monitors[idx].lastIAScore,
                            m_monitors[idx].lastTechScore,
                            m_monitors[idx].lastAlignScore,
                            m_monitors[idx].isAlignedM15 ? "OK" : "X",
                            m_monitors[idx].isAlignedM30 ? "OK" : "X",
                            m_monitors[idx].isAlignedH1 ? "OK" : "X");
   }
   
   int GetMonitorCount() { return m_monitorCount; }
   
   void UpdateSingleMonitorScores(ulong ticket, double iaScore, double techScore, double alignScore)
   {
      int idx = FindMonitorIndex(ticket);
      if(idx < 0) return;
      
      double oldCombo = (m_monitors[idx].lastIAScore * m_iaWeight) + 
                        (m_monitors[idx].lastTechScore * m_techWeight) + 
                        (m_monitors[idx].lastAlignScore * m_alignWeight);
      double newCombo = (iaScore * m_iaWeight) + (techScore * m_techWeight) + (alignScore * m_alignWeight);
      
      m_monitors[idx].lastIAScore = iaScore;
      m_monitors[idx].lastTechScore = techScore;
      m_monitors[idx].lastAlignScore = alignScore;
      m_monitors[idx].lastUpdateTime = TimeCurrent();
      
      if(newCombo > m_monitors[idx].peakCombinedScore)
         m_monitors[idx].peakCombinedScore = newCombo;
      
      if(m_dynamicDurationEnabled && m_closeOnScoreDrop)
      {
         datetime timeSinceEntry = TimeCurrent() - m_monitors[idx].entryTime;
         bool isSettled = (timeSinceEntry >= 120);
         
         double degradationThreshold = m_monitors[idx].peakCombinedScore * 0.6;
         bool significantDegradation = (newCombo < degradationThreshold && newCombo < m_minHoldScore);
         
         if(isSettled && (newCombo < m_minHoldScore || significantDegradation))
         {
            m_monitors[idx].consecutiveScoreDrops++;
            Print("Score drop #", m_monitors[idx].consecutiveScoreDrops, " for ", m_monitors[idx].symbol,
                  " Combined: ", DoubleToString(newCombo, 1), "% < ", DoubleToString(m_minHoldScore, 1), 
                  "% (Peak: ", DoubleToString(m_monitors[idx].peakCombinedScore, 1), "%)");
         }
         else
         {
            if(m_monitors[idx].consecutiveScoreDrops > 0)
               m_monitors[idx].consecutiveScoreDrops = 0;
         }
      }
   }
   
   bool CheckDynamicDuration(ulong ticket, bool &shouldClose, string &reason)
   {
      shouldClose = false;
      reason = "";
      
      if(!m_dynamicDurationEnabled) return true;
      
      int idx = FindMonitorIndex(ticket);
      if(idx < 0) return true;
      
      if(!m_position.SelectByTicket(ticket)) return false;
      
      double profit = m_position.Profit();
      
      if(profit <= 0)
      {
         return true;
      }
      
      double currentCombo = (m_monitors[idx].lastIAScore * m_iaWeight) + 
                            (m_monitors[idx].lastTechScore * m_techWeight) + 
                            (m_monitors[idx].lastAlignScore * m_alignWeight);
      
      bool isBuy = (m_monitors[idx].posType == POSITION_TYPE_BUY);
      
      if(m_closeOnScoreDrop && m_monitors[idx].consecutiveScoreDrops >= m_scoreDropBars && profit > 0)
      {
         shouldClose = true;
         reason = StringFormat("Score dropped below %.0f%% for %d bars - protecting profit %.2f", 
                               m_minHoldScore, m_scoreDropBars, profit);
         return false;
      }
      
      double entryCombo = (m_monitors[idx].entryIAScore * m_iaWeight) + 
                          (m_monitors[idx].entryTechScore * m_techWeight) + 
                          (m_monitors[idx].entryAlignScore * m_alignWeight);
      
      double degradationFromEntry = 0;
      double degradationFromPeak = 0;
      
      if(entryCombo > 1.0)
         degradationFromEntry = ((entryCombo - currentCombo) / entryCombo) * 100;
      if(m_monitors[idx].peakCombinedScore > 1.0)
         degradationFromPeak = ((m_monitors[idx].peakCombinedScore - currentCombo) / m_monitors[idx].peakCombinedScore) * 100;
      
      if(currentCombo > m_monitors[idx].peakCombinedScore)
         m_monitors[idx].peakCombinedScore = currentCombo;
      
      if(m_monitors[idx].peakCombinedScore > 70 && degradationFromPeak > 40 && currentCombo < 60 && profit > 0)
      {
         shouldClose = true;
         reason = StringFormat("Score degraded %.1f%% from peak - protecting profit %.2f", 
                               degradationFromPeak, profit);
         return false;
      }
      
      if(m_useMMCycleExit && profit > 0)
      {
         datetime tradeDuration = TimeCurrent() - m_monitors[idx].entryTime;
         
         bool dayThreeTrade = (tradeDuration >= 16 * 60 * 60);
         bool dayTwoTrade = (tradeDuration >= 8 * 60 * 60 && tradeDuration < 16 * 60 * 60);
         
         bool exitCondition = false;
         
         if(dayThreeTrade && currentCombo < 70)
         {
            exitCondition = true;
            reason = StringFormat("MM Day3 exit with profit %.2f: Trade >16h, score %.1f%%", profit, currentCombo);
         }
         else if(dayTwoTrade && currentCombo < 55 && degradationFromEntry > 30)
         {
            exitCondition = true;
            reason = StringFormat("MM Day2 exit with profit %.2f: Score %.1f%% degraded", profit, currentCombo);
         }
         
         if(exitCondition)
         {
            shouldClose = true;
            return false;
         }
      }
      
      bool signalReversed = false;
      if(isBuy && m_monitors[idx].lastTechScore < 30 && m_monitors[idx].lastAlignScore < 30)
         signalReversed = true;
      else if(!isBuy && m_monitors[idx].lastTechScore < 30 && m_monitors[idx].lastAlignScore < 30)
         signalReversed = true;
      
      if(signalReversed && profit > 0)
      {
         shouldClose = true;
         reason = StringFormat("Signal reversed - protecting profit %.2f", profit);
         return false;
      }
      
      return true;
   }
   
   void CheckAndUpdateMTFAlignment(ulong ticket)
   {
      if(!m_mtfMonitorEnabled) return;
      
      int idx = FindMonitorIndex(ticket);
      if(idx < 0) return;
      
      if(!m_position.SelectByTicket(ticket))
      {
         RemoveMonitor(ticket);
         return;
      }
      
      string symbol = m_monitors[idx].symbol;
      ENUM_POSITION_TYPE posType = m_monitors[idx].posType;
      
      bool alignM15, alignM30, alignH1;
      bool isAligned = CheckMTFAlignmentForPosition(symbol, posType, alignM15, alignM30, alignH1);
      
      m_monitors[idx].isAlignedM15 = alignM15;
      m_monitors[idx].isAlignedM30 = alignM30;
      m_monitors[idx].isAlignedH1 = alignH1;
      
      if(!isAligned)
      {
         m_monitors[idx].consecutiveMisalignments++;
         Print("MTF Misalignment #", m_monitors[idx].consecutiveMisalignments, 
               " for ", symbol, " [M15:", alignM15, " M30:", alignM30, " H1:", alignH1, "]",
               " IA:", DoubleToString(m_monitors[idx].lastIAScore, 0), "%",
               " Tech:", DoubleToString(m_monitors[idx].lastTechScore, 0), "%");
         
         if(m_monitors[idx].consecutiveMisalignments >= m_maxMisalignmentCount)
         {
            double profit = m_position.Profit();
            if(profit > 0 && m_closeLossOnMTFMisalign)
            {
               Print("Closing ", symbol, " due to MTF misalignment - protecting profit: ", DoubleToString(profit, 2));
               ClosePosition(ticket, "MTF misalignment - profit protected");
            }
            else
            {
               Print("Position ", symbol, " misaligned (", m_monitors[idx].consecutiveMisalignments, "x) - ",
                     "waiting for SL/TP");
               m_monitors[idx].consecutiveMisalignments = m_maxMisalignmentCount;
            }
         }
      }
      else
      {
         if(m_monitors[idx].consecutiveMisalignments > 0)
         {
            Print("MTF Realigned for ", symbol);
            m_monitors[idx].consecutiveMisalignments = 0;
         }
      }
   }
   
   void PrintAllMonitors()
   {
      Print("=== Active Position Monitors ===");
      for(int i = 0; i < ArraySize(m_monitors); i++)
      {
         Print("#", i+1, " ", m_monitors[i].symbol, 
               " Ticket:", m_monitors[i].ticket,
               " IA:", m_monitors[i].lastIAScore, "%",
               " Tech:", m_monitors[i].lastTechScore, "%",
               " M15:", (m_monitors[i].isAlignedM15 ? "OK" : "X"),
               " M30:", (m_monitors[i].isAlignedM30 ? "OK" : "X"),
               " H1:", (m_monitors[i].isAlignedH1 ? "OK" : "X"),
               " Misalign:", m_monitors[i].consecutiveMisalignments);
      }
   }
   
   void ClosePosition(ulong ticket, string reason)
   {
      if(!m_position.SelectByTicket(ticket)) return;
      
      double profit = m_position.Profit();
      string symbol = m_position.Symbol();
      
      if(m_trade.PositionClose(ticket))
      {
         m_totalTrades++;
         m_totalProfit += profit;
         if(profit > 0) m_winningTrades++;
         
         UpdateCapital(profit);
         
         Print("Position closed: ", symbol, " Reason: ", reason, 
               " Profit: ", profit, " New Capital: ", m_currentCapital);
      }
   }
   
   void CloseAllPositions(string reason)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!m_position.SelectByTicket(ticket)) continue;
         if(m_position.Magic() != m_magicNumber) continue;
         ClosePosition(ticket, reason);
      }
   }
   
   int CountPositions()
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i) && m_position.Magic() == m_magicNumber)
            count++;
      }
      return count;
   }
   
   bool HasPosition(string symbol)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i) && 
            m_position.Magic() == m_magicNumber &&
            m_position.Symbol() == symbol)
            return true;
      }
      return false;
   }
   
   double GetWinRate()
   {
      if(m_totalTrades == 0) return 0;
      return (double)m_winningTrades / m_totalTrades * 100;
   }
   
   double GetTotalProfit() { return m_totalProfit; }
   int GetTotalTrades() { return m_totalTrades; }
   int GetWinningTrades() { return m_winningTrades; }
};
