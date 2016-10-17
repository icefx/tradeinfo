//+------------------------------------------------------------------+
//|                                                    TradeInfo.mq4 |
//|                                         Copyright © 2016, Ice FX |
//|                                              http://www.icefx.eu |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2016, Ice FX <http://www.icefx.eu>"
#property link      "http://www.icefx.eu"
#property version   "1.98"
#property strict

#property indicator_separate_window
#property indicator_buffers 0

input bool    ShowProfitInfo          = TRUE;
input bool    ShowTodayRanges         = TRUE;
input bool    ShowRiskInfo            = FALSE;
input bool    ShowAccountOrderInfo    = TRUE;
input int     RiskStopLoss            = 0;
input string  RiskLevels              = "1,5,10,20,40,50,60,80,100";

input bool    OnlyAttachedSymbol      = FALSE;
input int     MagicNumber             = -1;
input string  CommentFilter           = "";
input string  StartDateFilter         = "";
input int     FontSize                = 8;
input bool    WhiteMode               = False;

int      windowIndex                   = 0;
string   preCurrSign                   = "";
string   postCurrSign                  = "";
double   pip_multiplier                = 1.0;
int      daySeconds                    = 86400;

double   MaxDD            = 0,
         MaxDDp           = 0,
         CurrentDD        = 0, 
         CurrentDDp       = 0;

datetime maxDDDay;
datetime startDateFilter = 0;
datetime LastDrawProfitInfo = 0;

string   IndiName                      = "TradeInfo v1.9.8";

/*******************  Version history  ********************************
   
   v1.9.8 - 2016.03.13
   --------------------
      - fixed 2-digits XAU

   v1.9.7 - 2016.03.07
   --------------------
      - support 2-digits CFDs

   v1.9.6 - 2015.12.30
   --------------------
      - show lots in profit info

   v1.9.5 - 2015.05.28
   --------------------
      - Number round problem fixed
      - Customizable risk levels. The value is a comma-separated string without percent sign. E.G.: 1,2,5,10,15

   v1.9.4 - 2014.08.27
   --------------------
      - White background mode

   v1.9.2 - 2013.11.13
   --------------------
      - Some percentage bug fixed
      
   v1.9.1 - 2013.11.04
   --------------------
      - Some bug fixed

   v1.9.0 - 2013.10.17
   --------------------
      - Added Estimated profit and max losses in pips
      - StartDateFilter: beállítható a profitszámítás kezdõ idõpontja
      - ShowRiskInfo default értéke false
      - Show daily and monthly average gain
      - ProfitInfo refresh only every 10 seconds


   v1.8.4 - 2013.08.15
   --------------------
      - Added Daily Max DrawDown info


   v1.8.3 - 2013.07.11
   --------------------
      - Added Leverage and Swap info


   v1.8.2 - 2013.07.11
   --------------------
      - Fixed some bug in pip calculation logic


   v1.8.1 - 2013.07.09
   --------------------
      - Fixed some bug in pip calculation logic


   v1.8.0 - 2013.06.27
   --------------------
      - Added this week, last week, this month, last month range

***********************************************************************/

//+------------------------------------------------------------------+
int init() {
//+------------------------------------------------------------------+
	IndicatorShortName(IndiName);
   //DeleteAllObject();

   SetPipMultiplier(Symbol());

   setCurrency();
   
   // Load today max DD from global
   maxDDDay     = getGlobalVar("TRADEINFO_DD_DAY", 0);
   if (maxDDDay >= iTime(Symbol(), PERIOD_D1, 0))
   {
      MaxDD    = getGlobalVar("TRADEINFO_MAXDD", 0);
      MaxDDp   = getGlobalVar("TRADEINFO_MAXDDP", 0);
   } else {
   
      maxDDDay = iTime(Symbol(), PERIOD_D1, 0);
      MaxDD    = 0;
      MaxDDp   = 0;      
   }
   
   if (StartDateFilter != "")
      startDateFilter = StrToTime(StartDateFilter);

   
   return(0);
}

//+------------------------------------------------------------------+
int start() {
//+------------------------------------------------------------------+
   DoWork(); 

   return(0); 
}

//+------------------------------------------------------------------+
void DoWork() {
//+------------------------------------------------------------------+
   windowIndex = WindowFind(IndiName);

   CalculateDailyDrawDown();

   if (ShowAccountOrderInfo) DrawAccountInfo();
   if (ShowAccountOrderInfo) DrawCurrentTrades();  
   if (ShowTodayRanges) DrawTodayRange();
   if (ShowProfitInfo) DrawProfitHistory();
   if (ShowRiskInfo) DrawRiskInfo(); 
   DrawCopyright();
}

//+------------------------------------------------------------------+
int deinit() {
//+------------------------------------------------------------------+
   DeleteAllObject();

   return(0);
}

//+------------------------------------------------------------------+
void CalculateDailyDrawDown() {
//+------------------------------------------------------------------+
   double balance = AccountBalance();

   if (balance != 0)
   {
      CurrentDD = 0.0 - ( AccountMargin() + (AccountBalance() - AccountEquity()));
      CurrentDDp = MathDiv(CurrentDD, balance) * 100.0;

      if (CurrentDD < MaxDD || iTime(Symbol(), PERIOD_D1, 0) > maxDDDay)
      {
         MaxDD    = CurrentDD;
         MaxDDp   = CurrentDDp;
         maxDDDay = iTime(Symbol(), PERIOD_D1, 0);
         
         // Save to Global
         setGlobalVar("TRADEINFO_MAXDD",  MaxDD);
         setGlobalVar("TRADEINFO_MAXDDP", MaxDDp);
         setGlobalVar("TRADEINFO_DD_DAY", maxDDDay);
      }

   }
}

//+------------------------------------------------------------------+
double ND(double value, int decimal = -1) { 
//+------------------------------------------------------------------+
   if (decimal == -1)
      decimal = Digits();
   
   return (NormalizeDouble(value, decimal)); 
}

//+------------------------------------------------------------------+
string CutAt(string& str, string sep) {
//+------------------------------------------------------------------+
   string res = "";
   
   int index = StringFind(str, sep, 0);
   if (index != -1)
   {
      if (index > 0) res = StringSubstr(str, 0, index);
      str = StringSubstr(str, index + StringLen(sep));    
   } else {
      res = str;
      str = "";
   }
   return(res);
}

//+------------------------------------------------------------------+
color levelColors[10] = {Lime, SpringGreen, SpringGreen, LawnGreen, Gold, Gold, DarkSalmon, Tomato, Tomato, FireBrick};
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void DrawRiskInfo() {
//+------------------------------------------------------------------+
   SetPipMultiplier(Symbol());

   if (RiskStopLoss > 0)
      DrawText(1, 0, 0, "Order Risk (SL=" + RiskStopLoss + ")", WhiteMode?Black:White, FontSize); 
   else
      DrawText(1, 0, 0, "Order Risk", WhiteMode?Black:White, FontSize); 
   
   DrawText(1, 1, 0, "-------------------", WhiteMode?Black:White, FontSize); 
   
   string levels = RiskLevels;
   int i = 0;
  
   while (StringLen(levels) > 0)
   {
      string c = StringTrimLeft(StringTrimRight(CutAt(levels, ",")));
      double value = StringToDouble(c);
      
      if (value != EMPTY_VALUE) {
      
         color clr = levelColors[ArraySize(levelColors) - 1];
         if ( i < ArraySize(levelColors))
            clr = levelColors[i];            
      
         DrawText(1, i + 2, 0, StringConcatenate(value, "%:   ", DTS(MM(value), 2) + " lot"), clr, FontSize); 
         i++;
         
      }
   } 
}

//+------------------------------------------------------------------+
void DrawAccountInfo() {
//+------------------------------------------------------------------+
   SetPipMultiplier(Symbol());

   int row = 1;
   string text;
   int colWidth1 = 200;
   color c = WhiteMode?DarkBlue:LightCyan;
   text = StringConcatenate("Balance:  ", MTS(AccountBalance())); 
   DrawText(0, row, 0, text, c, FontSize); 
   
   double eqPercent = 0;
   if (AccountBalance() > 0)
      eqPercent = MathDiv(AccountEquity(), AccountBalance() * 100.0);
   
   text = StringConcatenate("Equity:  ", MTS(AccountEquity()), "  (", DTS(eqPercent, 2), "%)"); 
   DrawText(0, row, colWidth1, text, c, FontSize); 
   row++;
   double marginLevel = 0;
   
   if (AccountMargin() > 0) marginLevel = MathDiv(AccountEquity(), AccountMargin() * 100.0);
   text = StringConcatenate("Margin: ", DTS(AccountMargin(), 2), "  (", DTS(marginLevel, 2), "%)"); 
   DrawText(0, row, 0, text, c, FontSize); 
   
   if (AccountFreeMargin() < 0)
      c = Red;
   text = StringConcatenate("Free margin: ", DTS(AccountFreeMargin(), 2)); 
   DrawText(0, row, colWidth1, text, c, FontSize); 
   row++;
   c = WhiteMode?DarkBlue:LightCyan;

   text = StringConcatenate("Leverage: 1:", AccountLeverage()); 
   DrawText(0, row, 0, text, c, FontSize); 
   
   text = StringConcatenate("Swap  Long: ", MTS(MarketInfo(Symbol(), MODE_SWAPLONG), 2), "  Short: ", MTS(MarketInfo(Symbol(), MODE_SWAPSHORT), 2)); 
   DrawText(0, row, colWidth1, text, c, FontSize); 
   row++;

   DrawText(0, row, 0, "------------------------------------------------------------------", Gray, FontSize); 
}

//+------------------------------------------------------------------+
bool IsValidOrder() {
//+------------------------------------------------------------------+
   if (!OnlyAttachedSymbol || OrderSymbol() == Symbol()) 
      if ( MagicNumber == -1 || MagicNumber == OrderMagicNumber() )
         if (CommentFilter == "" || StringFind(OrderComment(), CommentFilter) != -1)
            return(true);

   return(false);
}

//+------------------------------------------------------------------+
void DrawCurrentTrades() {
//+------------------------------------------------------------------+
   int buyCount, sellCount = 0;
   double buyProfit, sellProfit, buyLot, sellLot, buyPip, sellPip = 0;
   double slPip, tpPip;
   double allTPPips, allSLPips = 0;
   double maxLoss, maxProfit = 0;
   color c = White;
   string text = "";
   int colWidth1 = 200;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if ( IsValidOrder() )
         {
            slPip = 0;
            tpPip = 0;
            if (OrderType() == OP_BUY) {
               buyCount++;
               buyProfit += OrderProfit() + OrderSwap() + OrderCommission();
               buyLot += OrderLots();
               buyPip += point2pip(MarketInfo(OrderSymbol(), MODE_BID) - OrderOpenPrice(), OrderSymbol());

               if (OrderStopLoss() > 0.0) slPip = point2pip(OrderOpenPrice() - OrderStopLoss(), OrderSymbol());
               if (OrderTakeProfit() > 0.0) tpPip = point2pip(OrderTakeProfit() - OrderOpenPrice(), OrderSymbol());
                  
            } else if (OrderType() == OP_SELL) {
               sellCount++;
               sellProfit += OrderProfit() + OrderSwap() + OrderCommission();
               sellLot += OrderLots();
               sellPip += point2pip(OrderOpenPrice() - MarketInfo(OrderSymbol(), MODE_BID), OrderSymbol());

               if (OrderStopLoss() > 0.0) slPip = point2pip(OrderStopLoss() - OrderOpenPrice(), OrderSymbol());
               if (OrderTakeProfit() > 0.0) tpPip = point2pip(OrderOpenPrice() - OrderTakeProfit(), OrderSymbol());
            }         
            if (slPip != 0) {
               maxLoss -= pip2money(slPip, OrderLots(), OrderSymbol());
               allSLPips -= slPip;
            }
            
            if (tpPip != 0) {
               maxProfit += pip2money(tpPip, OrderLots(), OrderSymbol()) + OrderSwap() + OrderCommission();
               allTPPips += tpPip;
            }
            
         }

   SetPipMultiplier(Symbol());

   int row = 5;

   //Spread   
   double spread = MathDiv(MarketInfo(Symbol(), MODE_SPREAD), pip_multiplier);
   if (spread < 3) c = WhiteMode?DarkGreen:LawnGreen; else c = Crimson;   
   text = StringConcatenate("Spread: ", DTS(spread, 2)); 
   DrawText(0, row, 0, text, c, FontSize); 

   //Drawdown
   if (CurrentDD < 0) c = WhiteMode?Red:LightPink; else if (CurrentDD == 0.0) c = WhiteMode?Black:White; else c = WhiteMode?DarkGreen:LawnGreen;
   text = StringConcatenate("Current    DD: ", DTS(CurrentDD, 2), "   (" + DTS(CurrentDDp, 2), "%)"); 
   DrawText(0, row, colWidth1, text, c, FontSize); 
   row++;

   //Max daily Drawdown
   if (MaxDD < 0) c = WhiteMode?Red:LightPink; else if (MaxDD == 0.0) c = WhiteMode?Black:White; else c = WhiteMode?DarkGreen:LawnGreen;
   text = StringConcatenate("Daily Max DD: ", DTS(MaxDD, 2), "   (" + DTS(MaxDDp, 2), "%)"); 
   DrawText(0, row, colWidth1, text, c, FontSize); 
   row++;


   //Max loss + profit
   if (maxProfit < 0) c = FireBrick; else if (maxProfit > 0) c = WhiteMode?DarkGreen:LawnGreen; else c = WhiteMode?Black:White;
   text = StringConcatenate("Est. profit: ", MTS(maxProfit), "  (", DTS(allTPPips, 1), " pips)"); 
   DrawText(0, row, 0, text, c, FontSize); 

   if (maxLoss < 0) c = Red; else if (maxLoss > 0) c = WhiteMode?DarkGreen:LawnGreen; else c = WhiteMode?Black:White;
   double maxLossp = 0; if (AccountBalance() > 0) maxLossp = MathDiv(maxLoss, AccountBalance() * 100);
   text = StringConcatenate("Max loss:  ", MTS(maxLoss), "  (", DTS(allSLPips, 1), " pips)  (", DTS(maxLossp, 2), "%)"); 
   DrawText(0, row, colWidth1, text, c, FontSize); 
   row++;
   
   DrawText(0, row, 0, "------------------------------------------------------------------", Gray, FontSize); 
   row++;

   //Order counts
   c = WhiteMode?DimGray:Gainsboro;
   text = StringConcatenate("Long:  ", buyCount); 
   DrawText(0, row, 0, text, c, FontSize); 
   text = StringConcatenate("Short: ", sellCount); 
   DrawText(0, row + 1, 0, text, c, FontSize);  

   DrawText(0, row + 2, 0, "------------------------------------------------------------------", Gray, FontSize); 
   text = StringConcatenate("Total:  ", buyCount + sellCount); 
   DrawText(0, row + 3, 0, text, c, FontSize); 

   // Order lots
   text = StringConcatenate("LOT: ", DTS(buyLot, 2)); 
   DrawText(0, row, 65, text, c, FontSize); 
   text = StringConcatenate("LOT: ", DTS(sellLot, 2)); 
   DrawText(0, row + 1, 65, text, c, FontSize); 
   text = StringConcatenate("LOT: ", DTS(buyLot + sellLot, 2)); 
   DrawText(0, row + 3, 65, text, c, FontSize); 
   
   // Order profits
   if (buyProfit < 0) c = Crimson; else if (buyProfit == 0.0) c = WhiteMode?DimGray:Gainsboro; else c = WhiteMode?DarkGreen:LawnGreen;
   text = StringConcatenate("Profit: ", MTS(buyProfit), "   (", DTS(buyPip, 1), " pips)"); 
   DrawText(0, row, colWidth1, text, c, FontSize); 


   if (sellProfit < 0) c = Crimson; else if (sellProfit == 0.0) c = WhiteMode?DimGray:Gainsboro; else c = WhiteMode?DarkGreen:LawnGreen;
   text = StringConcatenate("Profit: ", MTS(sellProfit), "   (", DTS(sellPip, 1), " pips)"); 
   DrawText(0, row + 1, colWidth1, text, c, FontSize); 

   if (buyProfit + sellProfit < 0) c = Crimson; else if (buyProfit + sellProfit == 0.0) c = WhiteMode?DimGray:Gainsboro; else c = WhiteMode?DarkGreen:LawnGreen;
   text = StringConcatenate("Profit: ", MTS(buyProfit + sellProfit), "   (", DTS(buyPip + sellPip, 1), " pips)"); 
   DrawText(0, row + 3, colWidth1, text, c, FontSize); 
}

//+------------------------------------------------------------------+
void DrawProfitHistory() {
//+------------------------------------------------------------------+
   if (LastDrawProfitInfo > TimeCurrent() - 10) return;
   LastDrawProfitInfo = TimeCurrent();

   datetime day, today, now, prevDay;
   
   int xOffset = 150;
   if (!ShowRiskInfo) xOffset = 5;

   DrawText(1, 0, xOffset + 260, "DATE", Gray, FontSize); 
   DrawText(1, 0, xOffset + 210, "PIPS", Gray, FontSize); 
   DrawText(1, 0, xOffset + 130, "PROFIT", Gray, FontSize); 
   DrawText(1, 0, xOffset + 60, "GAIN %", Gray, FontSize); 
   DrawText(1, 0, xOffset     , "LOT", Gray, FontSize); 
   DrawText(1, 1, xOffset     , "====================================", Gray, FontSize); 

   now = TimeCurrent();
   today = StrToTime(TimeToStr(now, TIME_DATE));

   DrawDayHistoryLine(xOffset, today, now, 2, "Today");

   day = today; prevDay = GetPreviousDay(day - daySeconds);
   DrawDayHistoryLine(xOffset, prevDay, day, 3, "Yesterday");

   day = prevDay; prevDay = GetPreviousDay(day - daySeconds);
   DrawDayHistoryLine(xOffset, prevDay, day, 4);

   day = prevDay; prevDay = GetPreviousDay(day - daySeconds);
   DrawDayHistoryLine(xOffset, prevDay, day, 5);

   day = prevDay; prevDay = GetPreviousDay(day - daySeconds);
   DrawDayHistoryLine(xOffset, prevDay, day, 6);
   
   day = DateOfMonday();
   DrawDayHistoryLine(xOffset, day, now, 7, "Week");

   day = StrToTime(Year()+"."+Month()+".01");
   DrawDayHistoryLine(xOffset, day, now, 8, "Month");

   day = StrToTime(Year()+".01.01");
   DrawDayHistoryLine(xOffset, day, now, 9, "Year");
   
   DrawText(1, 10, xOffset, "-------------------------------------------------------------------", Gray, FontSize); 

   // Daily & Monthly profit
   if (AccountBalance() != 0.0)
   {
      double pips, profit, lots = 0;
      datetime firstOrderTime = GetHistoryInfoFromDate(day, now, pips, profit, lots);
      if (now - firstOrderTime != 0)
      {
         int oneDay = 86400; //int oneMonth = oneDay * 30.4;
         double daily   = MathDiv(MathDiv(profit, MathDiv(now - firstOrderTime, oneDay)), (AccountBalance() - profit)) * 100.0;
         double monthly = daily * 30.4;

         DrawText(1, 11, xOffset, StringConcatenate("Monthly: ", DTS(monthly, 2), "%"), ColorOnSign(monthly), FontSize); 
         DrawText(1, 11, xOffset + 150, StringConcatenate("Daily: ", DTS(daily, 2), "%"), ColorOnSign(daily), FontSize); 
      }
   }

   DrawText(1, 12, xOffset, "====================================", Gray, FontSize); 
}

//+------------------------------------------------------------------+
double MathDiv(double a, double b) {
//+------------------------------------------------------------------+
   if (b != 0.0)
      return(a/b);

   return(0.0);
}  

//+------------------------------------------------------------------+
void DrawDayHistoryLine(int xOffset, datetime prevDay, datetime day, int row, string header = "") {
//+------------------------------------------------------------------+
   if (header == "") header = TimeToStr(prevDay, TIME_DATE); 

   double pips, profit, percent, lots = 0.0;
   string text;
   
   GetHistoryInfoFromDate(prevDay, day, pips, profit, lots);
   double profitp = 0;
   if (AccountBalance() > 0) profitp = MathDiv(profit, (AccountBalance() - profit)) * 100.0;
   
   text = StringConcatenate(header, ": "); 
   DrawText(1, row, xOffset + 260, text, WhiteMode?DimGray:Gray, FontSize); 

   text = DTS(pips, 1); 
   DrawText(1, row, xOffset + 210, text, ColorOnSign(pips), FontSize); 

   text = MTS(profit); 
   DrawText(1, row, xOffset + 120, text, ColorOnSign(profit), FontSize); 

   text = StringConcatenate(DTS(profitp, 2), "%"); 
   DrawText(1, row, xOffset + 60, text, ColorOnSign(profitp), FontSize); 

   text = DTS(lots, 2); 
   DrawText(1, row, xOffset, text, ColorOnSign(profit), FontSize); 
}

//+------------------------------------------------------------------+
void DrawTodayRange() {
//+------------------------------------------------------------------+
   string text;
   
   SetPipMultiplier(Symbol());
   
   double todayPips = point2pip(iHigh(NULL, PERIOD_D1, 0) - iLow(NULL, PERIOD_D1, 0));
   double yesterdayPips = point2pip(iHigh(NULL, PERIOD_D1, 1) - iLow(NULL, PERIOD_D1, 1));

   double thisWeekPips = point2pip(iHigh(NULL, PERIOD_W1, 0) - iLow(NULL, PERIOD_W1, 0));
   double lastWeekPips = point2pip(iHigh(NULL, PERIOD_W1, 1) - iLow(NULL, PERIOD_W1, 1));

   double thisMonthPips = point2pip(iHigh(NULL, PERIOD_MN1, 0) - iLow(NULL, PERIOD_MN1, 0));
   double lastMonthPips = point2pip(iHigh(NULL, PERIOD_MN1, 1) - iLow(NULL, PERIOD_MN1, 1));
   
   int colWidth2 = 500;
   int colWidth3 = 620;
   int row = 1;
   color c = C'141,176,241';
   DrawText(0, row, colWidth2, "Today range:", c, FontSize);                  DrawText(0, row, colWidth3, StringConcatenate(DTS(todayPips, 1), " pips"), c, FontSize); 
   DrawText(0, row + 1, colWidth2, "Yesterday range:", c, FontSize);          DrawText(0, row + 1, colWidth3, StringConcatenate(DTS(yesterdayPips, 1), " pips"), c, FontSize); 
   row += 3;
   
   c = C'103,150,237';
   DrawText(0, row, colWidth2, "This week range:", c, FontSize);              DrawText(0, row, colWidth3, StringConcatenate(DTS(thisWeekPips, 1), " pips"), c, FontSize); 
   DrawText(0, row + 1, colWidth2, "Last week range:", c, FontSize);          DrawText(0, row + 1, colWidth3, StringConcatenate(DTS(lastWeekPips, 1), " pips"), c, FontSize); 
   row += 3;

   c = C'65,123,233';
   DrawText(0, row, colWidth2, "This month range:", c, FontSize);             DrawText(0, row, colWidth3, StringConcatenate(DTS(thisMonthPips, 1), " pips"), c, FontSize); 
   DrawText(0, row + 1, colWidth2, "Last month range:", c, FontSize);         DrawText(0, row + 1, colWidth3, StringConcatenate(DTS(lastMonthPips, 1), " pips"), c, FontSize); 
   row += 3;


   datetime nextCandleTime = (Period() * 60) - (TimeCurrent() - iTime(NULL, 0, 0));

   c = WhiteMode?Orange:Bisque;
   DrawText(0, row, colWidth2, "Next candle:", c, FontSize);                  DrawText(0, row, colWidth3, TimeToStr(nextCandleTime, TIME_SECONDS), c, FontSize); 
}

//+------------------------------------------------------------------+
void DrawCopyright() {
//+------------------------------------------------------------------+
   string text = StringConcatenate(IndiName, " - Created by Ice FX - www.icefx.eu"); 
   DrawText(3, 0, 0, text, DimGray, 7);
}

//+------------------------------------------------------------------+
datetime GetHistoryInfoFromDate(datetime prevDay, datetime day, double &pips, double &profit, double &lots) {
//+------------------------------------------------------------------+
   datetime res = day;
   int i, k = OrdersHistoryTotal();
   pips = 0;
   profit = 0;
   lots = 0;
  
   for (i = 0; i < k; i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
         if ( IsValidOrder() ) {
           if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
               if (day >= OrderCloseTime() && OrderCloseTime() >= prevDay && OrderCloseTime() > startDateFilter) {
                  profit += OrderProfit() + OrderCommission() + OrderSwap();

                  if (OrderType() == OP_BUY) {
                     pips += point2pip(OrderClosePrice() - OrderOpenPrice(), OrderSymbol());
                  }
                  if (OrderType() == OP_SELL) {
                     pips += point2pip(OrderOpenPrice() - OrderClosePrice(), OrderSymbol());
                  }                  
                  lots += OrderLots();
                  
                  if (OrderCloseTime() < res) res = OrderCloseTime();
               }
            }
         }
      }
   }
   return(res);
}

//+------------------------------------------------------------------+
datetime GetPreviousDay(datetime curDay) {
//+------------------------------------------------------------------+
   datetime prevDay = curDay;
   
   while (TimeDayOfWeek(prevDay) < 1 || TimeDayOfWeek(prevDay) > 5) prevDay -= daySeconds;
   return(prevDay);
}

//+------------------------------------------------------------------+
datetime DateOfMonday(int no = 0) {
//+------------------------------------------------------------------+
  datetime dt = StrToTime(TimeToStr(TimeCurrent(), TIME_DATE));

  while (TimeDayOfWeek(dt) != 1) dt -= daySeconds;
  dt += no * 7 * daySeconds;

  return(dt);
}

color ColorOnSign(double value) {
  color lcColor = WhiteMode?DimGray:Gray;

  if (value > 0) lcColor = WhiteMode?DarkGreen:Green;
  if (value < 0) lcColor = FireBrick;

  return(lcColor);
}

//+------------------------------------------------------------------+
double MM(double Risk) {
//+------------------------------------------------------------------+
   double SL = RiskStopLoss;
   double NewLOT = 0;

   string Symb = Symbol();                                                    // Symb default value
   double One_Lot = MarketInfo(Symb,MODE_MARGINREQUIRED);                     // margin for 1 LOT
   double Min_Lot = MarketInfo(Symb,MODE_MINLOT);                             // Minimum LOT
   double Max_Lot = MarketInfo(Symb,MODE_MAXLOT);                             // Maximum LOT
   double Step   = MarketInfo(Symb,MODE_LOTSTEP);                             // Lot step
   double Free   = AccountFreeMargin();                                       // Free margin
//-------------------------------------------------------------------------------
   if (SL > 0)                                                                // If set StopLoss
   {               
      double RiskAmount = AccountEquity() * (Risk / 100);                     // Calc risk in money
      double tickValue = MarketInfo(Symb, MODE_TICKVALUE) * pip_multiplier;   // Get how many pips 1 unit price
      
      if (tickValue * SL != 0) NewLOT = RiskAmount / (tickValue * SL);        // Divide Risk price with SL price
      if (Step > 0) NewLOT = MathFloor(NewLOT / Step) * Step; //Round         // Round LOT to step
   }
//-------------------------------------------------------------------------------
   else                                                                       // Dynamic LOT calculation
   {                                                        
      if (Risk > 100)                                                         // If greater then 100
         Risk = 100;                                                          // then 100%
      if (Risk == 0)                                                          // If 0
         NewLOT = Min_Lot;                                                    // then minimal LOT
      else                                                                    
         if (Step > 0 && One_Lot > 0) 
            NewLOT = MathFloor(Free * Risk / 100 / One_Lot / Step) * Step;    // Calc by Risk and round to step
   }
//-------------------------------------------------------------------------------
   if (NewLOT < Min_Lot)                                                      // If smaller than minimum
      NewLOT = Min_Lot;                                                       // set to minimum LOT
   if (NewLOT > Max_Lot)                                                      // If greater than maximum
      NewLOT = Max_Lot;                                                       // set to maximum LOT
//-------------------------------------------------------------------------------
   double margin = NewLOT * One_Lot;                                          // Calc the required margin for LOT
   if (margin > AccountFreeMargin())                                          // If greater than the free
   {                                                                          // Message, alert, ...etczenet, alert....stb.       
      //string msg = "You have not enough money! Free margin: " + DTS(AccountFreeMargin(), 2) + ", Require: " + DTS(margin, 2); 
      //Log.Warning(msg);
      //Print(msg);
      //Alert(msg);
      return(0);                                                              // Return with 0. Skip the order open
   }
   return(NewLOT);                            
}

//+------------------------------------------------------------------+
void setCurrency() {
//+------------------------------------------------------------------+
   string currSign = AccountCurrency();
   if (currSign == "USD") {
      preCurrSign = "$";
      postCurrSign = postCurrSign;   
   } else if (currSign == "EUR") {
      preCurrSign = "";
      postCurrSign = postCurrSign;   
   } else {
      preCurrSign = "";
      postCurrSign = postCurrSign;   
   }
}

//+------------------------------------------------------------------+
string MTS(double value, int decimal = 2) {
//+------------------------------------------------------------------+
   return(StringConcatenate(preCurrSign, DTS(value, decimal), postCurrSign));
}

//+------------------------------------------------------------------+
string DTS(double value, int decimal = 0) { return(DoubleToStr(value, decimal)); }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
double point2pip(double point, string Symb = "") {
//+------------------------------------------------------------------+
   if (Symb == "") Symb = Symbol();

   SetPipMultiplier(Symb);
   
   return(MathDiv(MathDiv(point, MarketInfo(Symb, MODE_POINT)), pip_multiplier));
}

//+------------------------------------------------------------------+
double pip2money(double pip, double lot, string Symb) {
//+------------------------------------------------------------------+
   if (Symb == "") Symb = Symbol();

   SetPipMultiplier(Symb);

   double tickSize = MarketInfo(Symb, MODE_TICKSIZE);
   if (tickSize != 0)
   {
      double onePipValue = MarketInfo(Symb, MODE_TICKVALUE) * (MarketInfo(Symb, MODE_POINT) / tickSize);
      return((pip * pip_multiplier) * onePipValue * lot);
   } else return(0);
}

//+------------------------------------------------------------------+
double SetPipMultiplier(string Symb, bool simple = false) {
//+------------------------------------------------------------------+
   pip_multiplier = 1;
   int digit = MarketInfo(Symb, MODE_DIGITS);
   
   if (simple)
   {
      if (digit % 4 != 0) pip_multiplier = 10; 
        
   } else {
      if (digit == 5 || 
         (digit == 3 && StringFind(Symb, "JPY") > -1) ||     // If 3 digits and currency is JPY
         (digit == 2 && StringFind(Symb, "XAU") > -1) ||     // If 2 digits and currency is gold
         (digit == 2 && StringFind(Symb, "GOLD") > -1) ||    // If 2 digits and currency is gold
         (digit == 3 && StringFind(Symb, "XAG") > -1) ||     // If 3 digits and currency is silver
         (digit == 3 && StringFind(Symb, "SILVER") > -1) ||  // If 3 digits and currency is silver
         (digit == 1))                                       // If 1 digit (CFDs)
            pip_multiplier = 10;
      else if (digit == 6 || 
         (digit == 4 && StringFind(Symb, "JPY") > -1) ||     // If 4 digits and currency is JPY
         (digit == 3 && StringFind(Symb, "XAU") > -1) ||     // If 3 digits and currency is gold
         (digit == 3 && StringFind(Symb, "GOLD") > -1) ||    // If 3 digits and currency is gold
         (digit == 4 && StringFind(Symb, "XAG") > -1) ||     // If 4 digits and currency is silver
         (digit == 4 && StringFind(Symb, "SILVER") > -1) ||  // If 4 digits and currency is silver
         (digit == 2))                                       // If 2 digit (CFDs)
            pip_multiplier = 100;
   }  
   //Print("PipMultiplier: ", pip_multiplier, ", Digits: ", Digits);
   return(pip_multiplier);
}

//+------------------------------------------------------------------+
void DrawText(int corner, int row, int xOffset, string text, color c, int size = 7) {
//+------------------------------------------------------------------+
   string objName = "TradeInfo_" + DTS(corner) + "_" + DTS(xOffset) + "_" + DTS(row);
   if (ObjectFind(objName) != 0) {
      ObjectCreate(objName, OBJ_LABEL, windowIndex, 0, 0);
      ObjectSet(objName, OBJPROP_CORNER, corner);
      ObjectSet(objName, OBJPROP_SELECTABLE, 0);
      ObjectSet(objName, OBJPROP_HIDDEN, 1);
   }

   ObjectSetText(objName, text, size, "Verdana", c);
   ObjectSet(objName, OBJPROP_XDISTANCE, 6 + xOffset);
   ObjectSet(objName, OBJPROP_YDISTANCE, 6 + row * (size + 6));
   ObjectSet(objName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
double getGlobalVar(string name, double defaultValue = EMPTY_VALUE) {
//+------------------------------------------------------------------+
   if (GlobalVariableCheck(name))
      return (GlobalVariableGet(name));
   else 
      return (defaultValue);
}

//+------------------------------------------------------------------+
string setGlobalVar(string name, double value = EMPTY_VALUE) {
//+------------------------------------------------------------------+
   if (value == EMPTY_VALUE)
      GlobalVariableDel(name);
   else  
      GlobalVariableSet(name, value);
      
   return(name);
}

//+------------------------------------------------------------------+
void DeleteAllObject() {
//+------------------------------------------------------------------+
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
      if(StringFind(ObjectName(i), "TradeInfo_", 0) >= 0)
         ObjectDelete(ObjectName(i));

}

