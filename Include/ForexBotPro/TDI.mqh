//+------------------------------------------------------------------+
//|                                                         TDI.mqh |
//|                              Forex Bot Pro v7.0 - TDI Indicator  |
//|                              Traders Dynamic Index Complete      |
//+------------------------------------------------------------------+
#property copyright "Forex Bot Pro"
#property version   "7.0"
#property strict

#include "Enums.mqh"

struct TDIResult
{
   double greenLine;
   double redLine;
   double upperBand;
   double lowerBand;
   double midLine;
   ENUM_SIGNAL_TYPE signal;
   double confidence;
   bool crossUp;
   bool crossDown;
   bool inOverbought;
   bool inOversold;
   bool sharkFinBullish;
   bool sharkFinBearish;
   bool mayoPattern;
   bool blueberryPattern;
};

class CTDIIndicator
{
private:
   int m_rsiPeriod;
   int m_pricePeriod;
   int m_signalPeriod;
   int m_volatilityBand;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   double m_rsiBuffer[];
   double m_greenLineBuffer[];
   double m_redLineBuffer[];
   double m_upperBandBuffer[];
   double m_lowerBandBuffer[];
   double m_midLineBuffer[];
   
public:
   CTDIIndicator()
   {
      m_rsiPeriod = 13;
      m_pricePeriod = 2;
      m_signalPeriod = 7;
      m_volatilityBand = 34;
      m_symbol = _Symbol;
      m_timeframe = PERIOD_M15;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES timeframe, int rsiPeriod=13, int pricePeriod=2, int signalPeriod=7, int volatilityBand=34)
   {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_rsiPeriod = rsiPeriod;
      m_pricePeriod = pricePeriod;
      m_signalPeriod = signalPeriod;
      m_volatilityBand = volatilityBand;
   }
   
   double CalculateRSI(const double &close[], int period, int pos)
   {
      if(pos < period) return 50.0;
      
      double gainSum = 0, lossSum = 0;
      for(int i = 1; i <= period; i++)
      {
         double change = close[pos - i + 1] - close[pos - i];
         if(change > 0)
            gainSum += change;
         else
            lossSum -= change;
      }
      
      double avgGain = gainSum / period;
      double avgLoss = lossSum / period;
      
      if(avgLoss == 0) return 100.0;
      double rs = avgGain / avgLoss;
      return 100.0 - (100.0 / (1.0 + rs));
   }
   
   double CalculateEMA(const double &data[], int period, int pos, double prevEMA)
   {
      double multiplier = 2.0 / (period + 1);
      return (data[pos] - prevEMA) * multiplier + prevEMA;
   }
   
   double CalculateSMA(const double &data[], int period, int pos)
   {
      if(pos < period - 1) return data[pos];
      
      double sum = 0;
      for(int i = 0; i < period; i++)
         sum += data[pos - i];
      return sum / period;
   }
   
   double CalculateStdDev(const double &data[], int period, int pos, double mean)
   {
      if(pos < period - 1) return 0;
      
      double sum = 0;
      for(int i = 0; i < period; i++)
      {
         double diff = data[pos - i] - mean;
         sum += diff * diff;
      }
      return MathSqrt(sum / period);
   }
   
   TDIResult Calculate(int lookback=100)
   {
      TDIResult result;
      result.greenLine = 50;
      result.redLine = 50;
      result.upperBand = 68;
      result.lowerBand = 32;
      result.midLine = 50;
      result.signal = SIGNAL_NEUTRAL;
      result.confidence = 50.0;
      result.crossUp = false;
      result.crossDown = false;
      result.inOverbought = false;
      result.inOversold = false;
      result.sharkFinBullish = false;
      result.sharkFinBearish = false;
      
      double close[];
      ArraySetAsSeries(close, true);
      int copied = CopyClose(m_symbol, m_timeframe, 0, lookback + m_volatilityBand + 50, close);
      
      if(copied < lookback + m_volatilityBand) return result;
      
      ArrayResize(m_rsiBuffer, copied);
      ArrayResize(m_greenLineBuffer, copied);
      ArrayResize(m_redLineBuffer, copied);
      ArrayResize(m_upperBandBuffer, copied);
      ArrayResize(m_lowerBandBuffer, copied);
      ArrayResize(m_midLineBuffer, copied);
      
      ArraySetAsSeries(m_rsiBuffer, true);
      ArraySetAsSeries(m_greenLineBuffer, true);
      ArraySetAsSeries(m_redLineBuffer, true);
      ArraySetAsSeries(m_upperBandBuffer, true);
      ArraySetAsSeries(m_lowerBandBuffer, true);
      ArraySetAsSeries(m_midLineBuffer, true);
      
      for(int i = copied - 1; i >= 0; i--)
         m_rsiBuffer[i] = CalculateRSI(close, m_rsiPeriod, copied - 1 - i);
      
      m_greenLineBuffer[copied-1] = m_rsiBuffer[copied-1];
      for(int i = copied - 2; i >= 0; i--)
         m_greenLineBuffer[i] = CalculateEMA(m_rsiBuffer, m_pricePeriod, i, m_greenLineBuffer[i+1]);
      
      m_redLineBuffer[copied-1] = m_rsiBuffer[copied-1];
      for(int i = copied - 2; i >= 0; i--)
         m_redLineBuffer[i] = CalculateEMA(m_rsiBuffer, m_signalPeriod, i, m_redLineBuffer[i+1]);
      
      for(int i = copied - m_volatilityBand; i >= 0; i--)
      {
         m_midLineBuffer[i] = CalculateSMA(m_rsiBuffer, m_volatilityBand, i);
         double stdDev = CalculateStdDev(m_rsiBuffer, m_volatilityBand, i, m_midLineBuffer[i]);
         m_upperBandBuffer[i] = m_midLineBuffer[i] + 1.6185 * stdDev;
         m_lowerBandBuffer[i] = m_midLineBuffer[i] - 1.6185 * stdDev;
      }
      
      result.greenLine = m_greenLineBuffer[0];
      result.redLine = m_redLineBuffer[0];
      result.upperBand = m_upperBandBuffer[0];
      result.lowerBand = m_lowerBandBuffer[0];
      result.midLine = m_midLineBuffer[0];
      
      result.crossUp = (m_greenLineBuffer[1] <= m_redLineBuffer[1] && m_greenLineBuffer[0] > m_redLineBuffer[0]);
      result.crossDown = (m_greenLineBuffer[1] >= m_redLineBuffer[1] && m_greenLineBuffer[0] < m_redLineBuffer[0]);
      
      result.inOverbought = (result.greenLine > 68 || result.redLine > 68);
      result.inOversold = (result.greenLine < 32 || result.redLine < 32);
      
      result.sharkFinBullish = DetectSharkFinBullish();
      result.sharkFinBearish = DetectSharkFinBearish();
      result.mayoPattern = DetectMayoPattern();
      result.blueberryPattern = DetectBlueberryPattern();
      
      if(result.crossUp && result.inOversold)
      {
         result.signal = SIGNAL_STRONG_BUY;
         result.confidence = 90.0;
      }
      else if(result.crossUp)
      {
         result.signal = SIGNAL_BUY;
         result.confidence = 75.0;
      }
      else if(result.crossDown && result.inOverbought)
      {
         result.signal = SIGNAL_STRONG_SELL;
         result.confidence = 90.0;
      }
      else if(result.crossDown)
      {
         result.signal = SIGNAL_SELL;
         result.confidence = 75.0;
      }
      else if(result.greenLine > result.redLine && result.greenLine > result.midLine)
      {
         result.signal = SIGNAL_WEAK_BUY;
         result.confidence = 60.0;
      }
      else if(result.greenLine < result.redLine && result.greenLine < result.midLine)
      {
         result.signal = SIGNAL_WEAK_SELL;
         result.confidence = 60.0;
      }
      else
      {
         result.signal = SIGNAL_NEUTRAL;
         result.confidence = 50.0;
      }
      
      return result;
   }
   
   bool DetectSharkFinBullish()
   {
      if(ArraySize(m_greenLineBuffer) < 10) return false;
      
      bool dippedBelow = false;
      int dipBar = -1;
      
      for(int i = 1; i < 8; i++)
      {
         if(m_greenLineBuffer[i] < m_lowerBandBuffer[i] ||
            m_greenLineBuffer[i] < 35)
         {
            dippedBelow = true;
            dipBar = i;
            break;
         }
      }
      
      if(!dippedBelow) return false;
      
      if(m_greenLineBuffer[0] > m_greenLineBuffer[dipBar] + 3 &&
         m_greenLineBuffer[0] > m_midLineBuffer[0] - 5)
      {
         bool sharpRise = true;
         for(int i = 0; i < dipBar; i++)
         {
            if(m_greenLineBuffer[i] < m_greenLineBuffer[i+1])
            {
               sharpRise = false;
               break;
            }
         }
         
         if(sharpRise) return true;
      }
      
      return false;
   }
   
   bool DetectSharkFinBearish()
   {
      if(ArraySize(m_greenLineBuffer) < 10) return false;
      
      bool spikedAbove = false;
      int spikeBar = -1;
      
      for(int i = 1; i < 8; i++)
      {
         if(m_greenLineBuffer[i] > m_upperBandBuffer[i] ||
            m_greenLineBuffer[i] > 65)
         {
            spikedAbove = true;
            spikeBar = i;
            break;
         }
      }
      
      if(!spikedAbove) return false;
      
      if(m_greenLineBuffer[0] < m_greenLineBuffer[spikeBar] - 3 &&
         m_greenLineBuffer[0] < m_midLineBuffer[0] + 5)
      {
         bool sharpFall = true;
         for(int i = 0; i < spikeBar; i++)
         {
            if(m_greenLineBuffer[i] > m_greenLineBuffer[i+1])
            {
               sharpFall = false;
               break;
            }
         }
         
         if(sharpFall) return true;
      }
      
      return false;
   }
   
   double GetGreenLine() { return m_greenLineBuffer[0]; }
   double GetRedLine() { return m_redLineBuffer[0]; }
   double GetUpperBand() { return m_upperBandBuffer[0]; }
   double GetLowerBand() { return m_lowerBandBuffer[0]; }
   double GetMidLine() { return m_midLineBuffer[0]; }
   
   bool DetectMayoPattern()
   {
      if(ArraySize(m_greenLineBuffer) < 10 || ArraySize(m_redLineBuffer) < 10) return false;
      
      bool greenTouchedLower = false;
      bool greenBouncedUp = false;
      
      for(int i = 1; i < 8; i++)
      {
         if(m_greenLineBuffer[i] <= m_lowerBandBuffer[i] + 2 ||
            m_greenLineBuffer[i] < 35)
         {
            greenTouchedLower = true;
            
            if(m_greenLineBuffer[0] > m_greenLineBuffer[i] + 5 &&
               m_greenLineBuffer[0] > m_redLineBuffer[0])
            {
               greenBouncedUp = true;
               break;
            }
         }
      }
      
      return (greenTouchedLower && greenBouncedUp);
   }
   
   bool DetectBlueberryPattern()
   {
      if(ArraySize(m_greenLineBuffer) < 10 || ArraySize(m_redLineBuffer) < 10) return false;
      
      bool greenTouchedUpper = false;
      bool greenBouncedDown = false;
      
      for(int i = 1; i < 8; i++)
      {
         if(m_greenLineBuffer[i] >= m_upperBandBuffer[i] - 2 ||
            m_greenLineBuffer[i] > 65)
         {
            greenTouchedUpper = true;
            
            if(m_greenLineBuffer[0] < m_greenLineBuffer[i] - 5 &&
               m_greenLineBuffer[0] < m_redLineBuffer[0])
            {
               greenBouncedDown = true;
               break;
            }
         }
      }
      
      return (greenTouchedUpper && greenBouncedDown);
   }
};
