#property copyright "ForexBotPro"
#property version   "1.00"

#include "Enums.mqh"

struct TelegramTradeInfo
{
   ulong    ticket;
   string   symbol;
   bool     isBuy;
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   lotSize;
   datetime openTime;
   double   currentPips;
   double   maxPips;
   double   minPips;
   bool     isActive;
   datetime lastUpdate;
};

struct DailyStats
{
   datetime date;
   int      totalTrades;
   int      wins;
   int      losses;
   double   totalPips;
   double   maxDrawdown;
   double   maxProfit;
};

class CTelegramNotifier
{
private:
   string   m_botToken;
   string   m_chatId;
   string   m_channelName;
   bool     m_enabled;
   int      m_gmtOffset;
   
   TelegramTradeInfo m_activeTrades[];
   int      m_activeTradeCount;
   
   DailyStats m_dailyStats;
   datetime m_lastDailySummary;
   
   int      m_updateInterval;
   datetime m_lastUpdate;
   
   string GetDirectionEmoji(bool isBuy)
   {
      return isBuy ? "🟢" : "🔴";
   }
   
   string GetDirectionText(bool isBuy)
   {
      return isBuy ? "#BUY" : "#SELL";
   }
   
   string GetFireEmoji()
   {
      return "🔥";
   }
   
   string GetTargetEmoji()
   {
      return "🎯";
   }
   
   string GetWarningEmoji()
   {
      return "⚠️";
   }
   
   string GetCheckEmoji()
   {
      return "✅";
   }
   
   string GetCrossEmoji()
   {
      return "❌";
   }
   
   string GetDiamondEmoji()
   {
      return "💎";
   }
   
   string GetChartEmoji()
   {
      return "📊";
   }
   
   string GetMoneyEmoji()
   {
      return "💰";
   }
   
   string GetRocketEmoji()
   {
      return "🚀";
   }
   
   string FormatPrice(double price, string symbol)
   {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      return DoubleToString(price, digits);
   }
   
   double CalculatePips(string symbol, double priceChange)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double pipValue = (digits == 3 || digits == 5) ? point * 10 : point;
      return priceChange / pipValue;
   }
   
   string UrlEncode(string text)
   {
      uchar utf8Bytes[];
      int bytesCount = StringToCharArray(text, utf8Bytes, 0, WHOLE_ARRAY, CP_UTF8);
      
      string result = "";
      
      for(int i = 0; i < bytesCount - 1; i++)
      {
         uchar ch = utf8Bytes[i];
         
         if((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || 
            (ch >= '0' && ch <= '9') || ch == '-' || ch == '_' || ch == '.' || ch == '~')
         {
            result += CharToString(ch);
         }
         else if(ch == ' ')
         {
            result += "%20";
         }
         else if(ch == '\n')
         {
            result += "%0A";
         }
         else
         {
            result += StringFormat("%%%02X", ch);
         }
      }
      
      return result;
   }
   
   bool SendRequest(string endpoint, string params)
   {
      if(!m_enabled || m_botToken == "" || m_chatId == "")
         return false;
      
      string url = "https://api.telegram.org/bot" + m_botToken + "/" + endpoint;
      
      char postData[];
      char result[];
      string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
      string resultHeaders;
      
      StringToCharArray(params, postData, 0, StringLen(params));
      ArrayResize(postData, StringLen(params));
      
      int timeout = 5000;
      int res = WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
      
      if(res == -1)
      {
         int error = GetLastError();
         if(error == 4014)
         {
            Print("TelegramNotifier: Add https://api.telegram.org to allowed URLs in Tools->Options->Expert Advisors");
         }
         else
         {
            Print("TelegramNotifier: WebRequest failed, error: ", error);
         }
         return false;
      }
      
      return (res == 200);
   }
   
   bool SendMessage(string message, string parseMode = "HTML")
   {
      string params = "chat_id=" + m_chatId + 
                      "&text=" + UrlEncode(message) + 
                      "&parse_mode=" + parseMode;
      
      return SendRequest("sendMessage", params);
   }
   
   long OpenM15Chart(string symbol)
   {
      long chartId = ChartOpen(symbol, PERIOD_M15);
      if(chartId <= 0)
      {
         Print("TelegramNotifier: Failed to open M15 chart for ", symbol);
         return -1;
      }
      
      ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
      ChartSetInteger(chartId, CHART_SHOW_GRID, false);
      ChartSetInteger(chartId, CHART_AUTOSCROLL, true);
      ChartSetInteger(chartId, CHART_SHIFT, true);
      ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, clrBlack);
      ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, clrWhite);
      ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, clrLime);
      ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, clrRed);
      ChartSetInteger(chartId, CHART_COLOR_CHART_UP, clrLime);
      ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, clrRed);
      
      ChartRedraw(chartId);
      Sleep(500);
      
      return chartId;
   }
   
   void DrawTradeLevels(long chartId, string symbol, double entryPrice, double sl, double tp, bool isBuy)
   {
      string prefix = "TG_LEVELS_";
      
      ObjectsDeleteAll(chartId, prefix);
      
      string entryName = prefix + "ENTRY";
      ObjectCreate(chartId, entryName, OBJ_HLINE, 0, 0, entryPrice);
      ObjectSetInteger(chartId, entryName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(chartId, entryName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(chartId, entryName, OBJPROP_WIDTH, 2);
      ObjectSetString(chartId, entryName, OBJPROP_TEXT, "ENTRY: " + DoubleToString(entryPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
      ObjectSetInteger(chartId, entryName, OBJPROP_SELECTABLE, false);
      
      string slName = prefix + "SL";
      ObjectCreate(chartId, slName, OBJ_HLINE, 0, 0, sl);
      ObjectSetInteger(chartId, slName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(chartId, slName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(chartId, slName, OBJPROP_WIDTH, 2);
      ObjectSetString(chartId, slName, OBJPROP_TEXT, "SL: " + DoubleToString(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
      ObjectSetInteger(chartId, slName, OBJPROP_SELECTABLE, false);
      
      string tpName = prefix + "TP";
      ObjectCreate(chartId, tpName, OBJ_HLINE, 0, 0, tp);
      ObjectSetInteger(chartId, tpName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(chartId, tpName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(chartId, tpName, OBJPROP_WIDTH, 2);
      ObjectSetString(chartId, tpName, OBJPROP_TEXT, "TP: " + DoubleToString(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
      ObjectSetInteger(chartId, tpName, OBJPROP_SELECTABLE, false);
      
      string titleName = prefix + "TITLE";
      ObjectCreate(chartId, titleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(chartId, titleName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(chartId, titleName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(chartId, titleName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(chartId, titleName, OBJPROP_FONTSIZE, 14);
      ObjectSetString(chartId, titleName, OBJPROP_FONT, "Arial Bold");
      ObjectSetString(chartId, titleName, OBJPROP_TEXT, symbol + " M15 - " + (isBuy ? "BUY" : "SELL"));
      ObjectSetInteger(chartId, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chartId, titleName, OBJPROP_SELECTABLE, false);
      
      ChartRedraw(chartId);
      Sleep(300);
   }
   
   bool CaptureChartScreenshot(long chartId, string &filename)
   {
      filename = "TG_Chart_" + IntegerToString((int)TimeCurrent()) + ".png";
      
      bool result = ChartScreenShot(chartId, filename, 800, 600, ALIGN_RIGHT);
      
      if(!result)
      {
         Print("TelegramNotifier: Failed to capture chart screenshot");
         return false;
      }
      
      Sleep(200);
      return true;
   }
   
   bool SendPhoto(string filepath, string caption = "")
   {
      if(!m_enabled || m_botToken == "" || m_chatId == "")
         return false;
      
      string fullPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + filepath;
      
      int fileHandle = FileOpen(filepath, FILE_READ|FILE_BIN);
      if(fileHandle == INVALID_HANDLE)
      {
         Print("TelegramNotifier: Cannot open file for sending: ", filepath);
         return false;
      }
      
      int fileSize = (int)FileSize(fileHandle);
      uchar fileData[];
      ArrayResize(fileData, fileSize);
      FileReadArray(fileHandle, fileData);
      FileClose(fileHandle);
      
      string boundary = "----WebKitFormBoundary" + IntegerToString(GetTickCount());
      
      string header1 = "--" + boundary + "\r\n";
      header1 += "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n";
      header1 += m_chatId + "\r\n";
      
      string header2 = "--" + boundary + "\r\n";
      header2 += "Content-Disposition: form-data; name=\"photo\"; filename=\"" + filepath + "\"\r\n";
      header2 += "Content-Type: image/png\r\n\r\n";
      
      string header3 = "";
      if(caption != "")
      {
         header3 = "--" + boundary + "\r\n";
         header3 += "Content-Disposition: form-data; name=\"caption\"\r\n\r\n";
         header3 += caption + "\r\n";
         
         header3 += "--" + boundary + "\r\n";
         header3 += "Content-Disposition: form-data; name=\"parse_mode\"\r\n\r\n";
         header3 += "HTML\r\n";
      }
      
      string footer = "\r\n--" + boundary + "--\r\n";
      
      uchar part1[], part2[], part3[], part4[];
      StringToCharArray(header1, part1, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(part1, ArraySize(part1) - 1);
      
      StringToCharArray(header2, part2, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(part2, ArraySize(part2) - 1);
      
      StringToCharArray(header3, part3, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(part3, ArraySize(part3) - 1);
      
      StringToCharArray(footer, part4, 0, WHOLE_ARRAY, CP_UTF8);
      ArrayResize(part4, ArraySize(part4) - 1);
      
      int totalSize = ArraySize(part1) + ArraySize(part2) + fileSize + ArraySize(part3) + ArraySize(part4);
      uchar postData[];
      ArrayResize(postData, totalSize);
      
      int pos = 0;
      ArrayCopy(postData, part1, pos);
      pos += ArraySize(part1);
      ArrayCopy(postData, part2, pos);
      pos += ArraySize(part2);
      ArrayCopy(postData, fileData, pos);
      pos += fileSize;
      ArrayCopy(postData, part3, pos);
      pos += ArraySize(part3);
      ArrayCopy(postData, part4, pos);
      
      string url = "https://api.telegram.org/bot" + m_botToken + "/sendPhoto";
      string headers = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";
      
      uchar result[];
      string resultHeaders;
      
      int res = WebRequest("POST", url, headers, 10000, postData, result, resultHeaders);
      
      if(res == -1)
      {
         int error = GetLastError();
         Print("TelegramNotifier: SendPhoto failed, error: ", error);
         return false;
      }
      
      FileDelete(filepath);
      
      return (res == 200);
   }
   
   int FindTradeIndex(ulong ticket)
   {
      for(int i = 0; i < m_activeTradeCount; i++)
      {
         if(m_activeTrades[i].ticket == ticket)
            return i;
      }
      return -1;
   }
   
   void AddActiveTrade(TelegramTradeInfo &info)
   {
      m_activeTradeCount++;
      ArrayResize(m_activeTrades, m_activeTradeCount);
      m_activeTrades[m_activeTradeCount - 1] = info;
   }
   
   void RemoveActiveTrade(int index)
   {
      if(index < 0 || index >= m_activeTradeCount) return;
      
      for(int i = index; i < m_activeTradeCount - 1; i++)
      {
         m_activeTrades[i] = m_activeTrades[i + 1];
      }
      
      m_activeTradeCount--;
      ArrayResize(m_activeTrades, m_activeTradeCount);
   }
   
   bool IsNewDay()
   {
      datetime now = TimeCurrent();
      MqlDateTime nowStruct, lastStruct;
      TimeToStruct(now, nowStruct);
      TimeToStruct(m_dailyStats.date, lastStruct);
      
      return (nowStruct.day != lastStruct.day || 
              nowStruct.mon != lastStruct.mon || 
              nowStruct.year != lastStruct.year);
   }
   
   void ResetDailyStats()
   {
      m_dailyStats.date = TimeCurrent();
      m_dailyStats.totalTrades = 0;
      m_dailyStats.wins = 0;
      m_dailyStats.losses = 0;
      m_dailyStats.totalPips = 0;
      m_dailyStats.maxDrawdown = 0;
      m_dailyStats.maxProfit = 0;
   }

public:
   CTelegramNotifier()
   {
      m_botToken = "";
      m_chatId = "";
      m_channelName = "FOREXBOTPRO | Señales Premium";
      m_enabled = false;
      m_gmtOffset = 0;
      m_activeTradeCount = 0;
      m_updateInterval = 300;
      m_lastUpdate = 0;
      m_lastDailySummary = 0;
      ResetDailyStats();
   }
   
   ~CTelegramNotifier()
   {
      ArrayFree(m_activeTrades);
   }
   
   bool Initialize(string botToken, string chatId, int gmtOffset = 0)
   {
      m_botToken = botToken;
      m_chatId = chatId;
      m_gmtOffset = gmtOffset;
      m_enabled = (botToken != "" && chatId != "");
      
      if(m_enabled)
      {
         Print("TelegramNotifier: Initialized successfully");
         string testMsg = GetRocketEmoji() + " <b>ForexBotPro v7.0</b>\n" +
                          GetCheckEmoji() + " Sistema de señales activado\n" +
                          GetChartEmoji() + " Monitoreando mercados...";
         SendMessage(testMsg);
      }
      
      return m_enabled;
   }
   
   void SetChannelName(string name)
   {
      m_channelName = name;
   }
   
   void SetUpdateInterval(int seconds)
   {
      m_updateInterval = seconds;
   }
   
   void SetEnabled(bool enabled)
   {
      m_enabled = enabled;
   }
   
   bool IsEnabled()
   {
      return m_enabled;
   }
   
   bool SendChartWithLevels(string symbol, bool isBuy, double entryPrice, double sl, double tp, string caption = "")
   {
      if(!m_enabled) return false;
      
      long chartId = OpenM15Chart(symbol);
      if(chartId <= 0) return false;
      
      DrawTradeLevels(chartId, symbol, entryPrice, sl, tp, isBuy);
      
      string filename;
      bool captured = CaptureChartScreenshot(chartId, filename);
      
      ChartClose(chartId);
      
      if(!captured) return false;
      
      if(caption == "")
      {
         caption = "<b>" + symbol + " M15</b>\n";
         caption += (isBuy ? "🟢 BUY" : "🔴 SELL") + "\n";
         caption += "━━━━━━━━━━━━━━━\n";
         caption += "🟡 Entry: " + FormatPrice(entryPrice, symbol) + "\n";
         caption += "🔴 SL: " + FormatPrice(sl, symbol) + "\n";
         caption += "🟢 TP: " + FormatPrice(tp, symbol);
      }
      
      return SendPhoto(filename, caption);
   }
   
   void SendSignalAlert(string symbol, bool isBuy, double entryPrice, double sl, double tp,
                        double iaScore, double techScore, double alignScore, double totalScore,
                        string pattern = "", string killZone = "")
   {
      if(!m_enabled) return;
      
      string header = "<b>" + m_channelName + "</b>\n";
      header += "━━━━━━━━━━━━━━━━━━━━━\n";
      
      string direction = GetFireEmoji() + " <b>" + GetDirectionText(isBuy) + " " + symbol + "</b> " + GetFireEmoji() + "\n\n";
      
      string priceInfo = GetDiamondEmoji() + " <b>Entrada:</b> " + FormatPrice(entryPrice, symbol) + "\n";
      priceInfo += GetCrossEmoji() + " <b>SL:</b> " + FormatPrice(sl, symbol) + "\n";
      priceInfo += GetCheckEmoji() + " <b>TP:</b> " + FormatPrice(tp, symbol) + "\n\n";
      
      double slPips = MathAbs(CalculatePips(symbol, entryPrice - sl));
      double tpPips = MathAbs(CalculatePips(symbol, tp - entryPrice));
      
      string riskInfo = GetChartEmoji() + " <b>Riesgo:</b> " + DoubleToString(slPips, 1) + " pips\n";
      riskInfo += GetTargetEmoji() + " <b>Objetivo:</b> " + DoubleToString(tpPips, 1) + " pips\n";
      riskInfo += GetMoneyEmoji() + " <b>Ratio:</b> 1:" + DoubleToString(tpPips/slPips, 1) + "\n\n";
      
      string scoreInfo = "<b>📈 Análisis:</b>\n";
      scoreInfo += "• IA Score: " + DoubleToString(iaScore, 1) + "%\n";
      scoreInfo += "• Technical: " + DoubleToString(techScore, 1) + "%\n";
      scoreInfo += "• Alignment: " + DoubleToString(alignScore, 1) + "%\n";
      scoreInfo += "• <b>TOTAL: " + DoubleToString(totalScore, 1) + "%</b>\n\n";
      
      string extraInfo = "";
      if(pattern != "")
         extraInfo += "🕯 Patrón: " + pattern + "\n";
      if(killZone != "")
         extraInfo += "⏰ Sesión: " + killZone + "\n";
      
      string footer = "\n━━━━━━━━━━━━━━━━━━━━━\n";
      footer += "⚡ <i>Señal generada por IA</i>";
      
      string fullMessage = header + direction + priceInfo + riskInfo + scoreInfo + extraInfo + footer;
      
      SendMessage(fullMessage);
   }
   
   void SendTradeConfirmation(ulong ticket, string symbol, bool isBuy, double entryPrice,
                               double sl, double tp, double lotSize)
   {
      if(!m_enabled) return;
      
      TelegramTradeInfo info;
      info.ticket = ticket;
      info.symbol = symbol;
      info.isBuy = isBuy;
      info.entryPrice = entryPrice;
      info.stopLoss = sl;
      info.takeProfit = tp;
      info.lotSize = lotSize;
      info.openTime = TimeCurrent();
      info.currentPips = 0;
      info.maxPips = 0;
      info.minPips = 0;
      info.isActive = true;
      info.lastUpdate = TimeCurrent();
      
      AddActiveTrade(info);
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += GetCheckEmoji() + " <b>ORDEN EJECUTADA</b> " + GetCheckEmoji() + "\n\n";
      msg += GetDirectionEmoji(isBuy) + " " + GetDirectionText(isBuy) + " " + symbol + "\n";
      msg += "📍 Entrada: " + FormatPrice(entryPrice, symbol) + "\n";
      msg += "📦 Lote: " + DoubleToString(lotSize, 2) + "\n";
      msg += "🎫 Ticket: #" + IntegerToString(ticket) + "\n";
      msg += "\n<i>Seguimiento activo iniciado...</i>";
      
      SendMessage(msg);
      
      m_dailyStats.totalTrades++;
   }
   
   void SendTradeUpdate(ulong ticket, double currentPrice, double currentPips, 
                        string status = "")
   {
      if(!m_enabled) return;
      
      int index = FindTradeIndex(ticket);
      if(index < 0) return;
      
      datetime now = TimeCurrent();
      if(now - m_activeTrades[index].lastUpdate < m_updateInterval)
         return;
      
      m_activeTrades[index].currentPips = currentPips;
      m_activeTrades[index].lastUpdate = now;
      
      if(currentPips > m_activeTrades[index].maxPips)
         m_activeTrades[index].maxPips = currentPips;
      if(currentPips < m_activeTrades[index].minPips)
         m_activeTrades[index].minPips = currentPips;
      
      string pipsEmoji = currentPips >= 0 ? "🟢" : "🔴";
      string pipsSign = currentPips >= 0 ? "+" : "";
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += GetChartEmoji() + " <b>ACTUALIZACIÓN</b>\n\n";
      msg += GetDirectionEmoji(m_activeTrades[index].isBuy) + " " + m_activeTrades[index].symbol + "\n";
      msg += "📍 Entrada: " + FormatPrice(m_activeTrades[index].entryPrice, m_activeTrades[index].symbol) + "\n";
      msg += "💹 Actual: " + FormatPrice(currentPrice, m_activeTrades[index].symbol) + "\n";
      msg += pipsEmoji + " P/L: <b>" + pipsSign + DoubleToString(currentPips, 1) + " pips</b>\n";
      
      if(status != "")
         msg += "\n📢 " + status;
      
      SendMessage(msg);
   }
   
   void SendBreakevenNotification(ulong ticket)
   {
      if(!m_enabled) return;
      
      int index = FindTradeIndex(ticket);
      if(index < 0) return;
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += "🛡 <b>BREAKEVEN ACTIVADO</b> 🛡\n\n";
      msg += GetDirectionEmoji(m_activeTrades[index].isBuy) + " " + m_activeTrades[index].symbol + "\n";
      msg += "✅ SL movido a entrada\n";
      msg += "💰 Ganancia protegida: +" + DoubleToString(m_activeTrades[index].maxPips, 1) + " pips\n";
      msg += "\n<i>Operación sin riesgo</i>";
      
      SendMessage(msg);
   }
   
   void SendTrailingStopUpdate(ulong ticket, double newSL, double lockedPips)
   {
      if(!m_enabled) return;
      
      int index = FindTradeIndex(ticket);
      if(index < 0) return;
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += "📈 <b>TRAILING STOP</b>\n\n";
      msg += GetDirectionEmoji(m_activeTrades[index].isBuy) + " " + m_activeTrades[index].symbol + "\n";
      msg += "🔒 Nuevo SL: " + FormatPrice(newSL, m_activeTrades[index].symbol) + "\n";
      msg += "💰 Pips asegurados: +" + DoubleToString(lockedPips, 1) + "\n";
      
      SendMessage(msg);
   }
   
   void SendTradeClose(ulong ticket, double closePips, bool isWin, string reason = "")
   {
      if(!m_enabled) return;
      
      int index = FindTradeIndex(ticket);
      if(index < 0) return;
      
      string resultEmoji = isWin ? GetCheckEmoji() : GetCrossEmoji();
      string resultText = isWin ? "GANANCIA" : "PÉRDIDA";
      string pipsSign = closePips >= 0 ? "+" : "";
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += resultEmoji + " <b>OPERACIÓN CERRADA</b> " + resultEmoji + "\n\n";
      msg += GetDirectionEmoji(m_activeTrades[index].isBuy) + " " + m_activeTrades[index].symbol + "\n";
      msg += "📍 Entrada: " + FormatPrice(m_activeTrades[index].entryPrice, m_activeTrades[index].symbol) + "\n";
      msg += "📊 Resultado: <b>" + resultText + "</b>\n";
      msg += "💰 P/L: <b>" + pipsSign + DoubleToString(closePips, 1) + " pips</b>\n";
      msg += "📈 Máx: +" + DoubleToString(m_activeTrades[index].maxPips, 1) + " pips\n";
      msg += "📉 Mín: " + DoubleToString(m_activeTrades[index].minPips, 1) + " pips\n";
      
      if(reason != "")
         msg += "\n📢 " + reason;
      
      SendMessage(msg);
      
      m_dailyStats.totalPips += closePips;
      if(isWin)
      {
         m_dailyStats.wins++;
         if(closePips > m_dailyStats.maxProfit)
            m_dailyStats.maxProfit = closePips;
      }
      else
      {
         m_dailyStats.losses++;
         if(closePips < m_dailyStats.maxDrawdown)
            m_dailyStats.maxDrawdown = closePips;
      }
      
      RemoveActiveTrade(index);
   }
   
   void SendTrendChangeAlert(string symbol, string oldTrend, string newTrend, 
                             string reason = "")
   {
      if(!m_enabled) return;
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += GetWarningEmoji() + " <b>CAMBIO DE TENDENCIA</b> " + GetWarningEmoji() + "\n\n";
      msg += "📊 " + symbol + "\n";
      msg += "❌ Anterior: " + oldTrend + "\n";
      msg += "✅ Nueva: " + newTrend + "\n";
      
      if(reason != "")
         msg += "\n📢 " + reason;
      
      SendMessage(msg);
   }
   
   void SendDailySummary()
   {
      if(!m_enabled) return;
      
      datetime now = TimeCurrent();
      MqlDateTime nowStruct;
      TimeToStruct(now, nowStruct);
      
      if(nowStruct.hour != 23 || nowStruct.min > 5)
         return;
      
      if(now - m_lastDailySummary < 3600)
         return;
      
      m_lastDailySummary = now;
      
      double winRate = m_dailyStats.totalTrades > 0 ? 
                       (double)m_dailyStats.wins / m_dailyStats.totalTrades * 100 : 0;
      
      string pipsEmoji = m_dailyStats.totalPips >= 0 ? "🟢" : "🔴";
      string pipsSign = m_dailyStats.totalPips >= 0 ? "+" : "";
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += GetChartEmoji() + " <b>RESUMEN DEL DÍA</b> " + GetChartEmoji() + "\n";
      msg += "📅 " + TimeToString(now, TIME_DATE) + "\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n\n";
      
      msg += "📊 <b>Estadísticas:</b>\n";
      msg += "• Total operaciones: " + IntegerToString(m_dailyStats.totalTrades) + "\n";
      msg += "• Ganadas: " + IntegerToString(m_dailyStats.wins) + " " + GetCheckEmoji() + "\n";
      msg += "• Perdidas: " + IntegerToString(m_dailyStats.losses) + " " + GetCrossEmoji() + "\n";
      msg += "• Win Rate: " + DoubleToString(winRate, 1) + "%\n\n";
      
      msg += pipsEmoji + " <b>PIPS TOTALES: " + pipsSign + DoubleToString(m_dailyStats.totalPips, 1) + "</b>\n\n";
      
      msg += "📈 Mejor trade: +" + DoubleToString(m_dailyStats.maxProfit, 1) + " pips\n";
      msg += "📉 Peor trade: " + DoubleToString(m_dailyStats.maxDrawdown, 1) + " pips\n";
      
      msg += "\n━━━━━━━━━━━━━━━━━━━━━\n";
      msg += "🔔 <i>Próxima sesión mañana</i>";
      
      SendMessage(msg);
      
      ResetDailyStats();
   }
   
   void SendActiveTradesSummary()
   {
      if(!m_enabled || m_activeTradeCount == 0) return;
      
      string msg = "<b>" + m_channelName + "</b>\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n";
      msg += GetRocketEmoji() + " <b>TRADES ACTIVOS</b> (" + IntegerToString(m_activeTradeCount) + ")\n";
      msg += "━━━━━━━━━━━━━━━━━━━━━\n\n";
      
      double totalPips = 0;
      
      for(int i = 0; i < m_activeTradeCount; i++)
      {
         string pipsEmoji = m_activeTrades[i].currentPips >= 0 ? "🟢" : "🔴";
         string pipsSign = m_activeTrades[i].currentPips >= 0 ? "+" : "";
         
         msg += GetDirectionEmoji(m_activeTrades[i].isBuy) + " " + m_activeTrades[i].symbol;
         msg += " | " + pipsEmoji + " " + pipsSign + DoubleToString(m_activeTrades[i].currentPips, 1) + " pips\n";
         
         totalPips += m_activeTrades[i].currentPips;
      }
      
      string totalEmoji = totalPips >= 0 ? "🟢" : "🔴";
      string totalSign = totalPips >= 0 ? "+" : "";
      
      msg += "\n━━━━━━━━━━━━━━━━━━━━━\n";
      msg += totalEmoji + " <b>TOTAL: " + totalSign + DoubleToString(totalPips, 1) + " pips</b>";
      
      SendMessage(msg);
   }
   
   void OnTick()
   {
      if(!m_enabled) return;
      
      if(IsNewDay())
      {
         SendDailySummary();
      }
      
      datetime now = TimeCurrent();
      if(now - m_lastUpdate >= m_updateInterval)
      {
         m_lastUpdate = now;
         
         for(int i = 0; i < m_activeTradeCount; i++)
         {
            if(m_activeTrades[i].isActive)
            {
               string symbol = m_activeTrades[i].symbol;
               double currentPrice = m_activeTrades[i].isBuy ? 
                                     SymbolInfoDouble(symbol, SYMBOL_BID) :
                                     SymbolInfoDouble(symbol, SYMBOL_ASK);
               
               double priceDiff = m_activeTrades[i].isBuy ?
                                  currentPrice - m_activeTrades[i].entryPrice :
                                  m_activeTrades[i].entryPrice - currentPrice;
               
               double currentPips = CalculatePips(symbol, priceDiff);
               m_activeTrades[i].currentPips = currentPips;
               
               if(currentPips > m_activeTrades[i].maxPips)
                  m_activeTrades[i].maxPips = currentPips;
               if(currentPips < m_activeTrades[i].minPips)
                  m_activeTrades[i].minPips = currentPips;
            }
         }
      }
   }
   
   int GetActiveTradeCount()
   {
      return m_activeTradeCount;
   }
   
   DailyStats GetDailyStats()
   {
      return m_dailyStats;
   }
};
