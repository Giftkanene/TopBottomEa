//+------------------------------------------------------------------+
//|                                                    TopBottom.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
  CTrade          trade;
  CPositionInfo   posinfo;
  COrderInfo      ordinfo;

//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+
input double  Lots                   = 0.1;             //Lot Size
input bool    CompoundIntrestSwitch  = false;           //Risk in base point instead of fixed lots 
input int     Risk                   = 40;              //Risk per trade in base points 
input bool    ParameterSwitching     = false;           //Different settings for different pairs 
input int     Volatility             = 110;             //Volutility for williams %R period
input int     StopLoss               = 800;
input int     Profit                 = 300;
input double  PointDifferenceLimit   = 50.0;            //Max spread allowed in points
input bool    DisplaySwitch          = true; 
input int     Magic                  = 1000;
input string  CommentName            ="TopBottomEa";

//+------------------------------------------------------------------+
//| Input Dependent Variables                                        |
//+------------------------------------------------------------------+
int     volatilityThreshold   = Volatility;     // volatility settings 
int     stopLossPoints        = StopLoss;       // sl in pips           
int     takeProfitPoints      = Profit;         // tp in pips 
int     maxBandWidth          = 1000;           // bollinger max bandwidth
int     minBandwidth          = 150;            // bollinger min bandwidth 
double  calculateLotSize      = 0.0;            // dynamic lot calculations 

//+------------------------------------------------------------------+
//| Account/Trading Parameters                                       |
//+------------------------------------------------------------------+
double  accountBalanceDivisor   = 1000000;      //risk calculations 
int     maxSlippage             = 30;           //max allowed slippage 
bool    tradingAllowed          = true;         //master trading switch

//+------------------------------------------------------------------+
//| Indicator parameteres                                            |
//+------------------------------------------------------------------+

int  wprThreshold            = 5;
int  handleBollinger;
int  handleWRP;

//+------------------------------------------------------------------+
//| Time Management                                                  |
//+------------------------------------------------------------------+
int         startTradingHour1   = 20;
int         endTradingHour1     = 24;
int         startTradingHour2   = 0;
int         endTradingHour2     = 3;
datetime    lastSignalTime      = 0;
datetime    lastBarTime         = 0;      // current bar timestamp
MqlDateTime BrokerTime, GMTTime;          // Time Structures 


//+------------------------------------------------------------------+
//| Position Tracking                                                |
//+------------------------------------------------------------------+
int buyPositionCount  = 0;      // we will use these to check how many buy or sell positions are there before placing an order 
int sellPositionCount = 0;  

//+------------------------------------------------------------------+
//| lot and price managment                                          |
//+------------------------------------------------------------------+
double totalBuyLots     = 0.0;      // total buy volume 
double totalSellLots    = 0.0;      // total sell volume 
double buyPrice         = 0.0;      // avg buy entry
double sellPrice        = 0.0;      // avg sell entry 
double buyStopLoss      = 0.0;      // buy sl price 
double sellStopLoss     = 0.0;      // sell sl price 

//+------------------------------------------------------------------+
//| Profit Tracking                                                  |
//+------------------------------------------------------------------+
double totalBuyProfit   = 0.0;    // Buy PnL
double totalSellProfit  = 0.0;    // Sell PnL


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){

  trade.SetExpertMagicNumber(Magic);
  ChartSetInteger(0,CHART_SHOW_GRID,false); // removes the gridlines from the chart the ea is running on 

  //function to set up parameter switching 
  if(ParameterSwitching){
    if(StringFind(_Symbol,"CHFSGD",0) < 0 && StringFind(_Symbol,"GBPSGD",0) < 0){
      // if these pairs are not found then these values should be used 
      volatilityThreshold   = Volatility;
      stopLossPoints = StopLoss;
      takeProfitPoints = Profit;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    else{
      // if the pairs are found then these values will be set 
      volatilityThreshold = 35;
      stopLossPoints = StopLoss;
      takeProfitPoints = Profit;
      maxBandWidth = 1000;
      minBandwidth = 0;
    }
  }
  else{
    if(StringFind(_Symbol,"GBPCAD",0) >= 0){
      // default values for GBPCAD
      volatilityThreshold = 110;
      stopLossPoints = 800;
      takeProfitPoints = 300;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    if(StringFind(_Symbol,"EURSGD",0) >= 0){
      volatilityThreshold = 140;
      stopLossPoints = 700;
      takeProfitPoints = 160;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    if(StringFind(_Symbol,"GBPCHF",0) >= 0){
      volatilityThreshold = 110;
      stopLossPoints = 600;
      takeProfitPoints = 200;
      maxBandWidth = 1000;
      minBandwidth = 150;
    }
    if(StringFind(_Symbol,"CHFSGD",0) >= 0){
      volatilityThreshold = 60;
      stopLossPoints = 700;
      takeProfitPoints = 160;
      maxBandWidth = 1000;
      minBandwidth = 0;
    }
    if(StringFind(_Symbol,"GBPSGD",0) >= 0){
      volatilityThreshold = 35;
      stopLossPoints = 700;
      takeProfitPoints = 160;
      maxBandWidth = 1000;
      minBandwidth = 0;
    }
  }
    // hide the indicators 
    TesterHideIndicators(true);

    // asign indicator handles 
    handleBollinger = iBands(_Symbol,PERIOD_M1,20,0,2.0,PRICE_CLOSE);
    handleWRP       = iWPR(_Symbol,PERIOD_M1,volatilityThreshold);

    //show the display panel
    if(DisplaySwitch){
      //CreateDisplayPanel();
    }

  
  return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
    // remove all the objects from the charts
    ObjectDelete(0,"tb_");
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){


  // variables 
  double upperBolligerBand, lowerBolllingerBand, currentWPR, indBuffer[];
  
  // copy the indicater values into the defined arrays
  CopyBuffer(handleBollinger,1,0,1,indBuffer);  // MODE_UPPER
  upperBolligerBand = indBuffer[0];

  CopyBuffer(handleBollinger,2,0,1,indBuffer);  // MODE_LOWER
  lowerBolllingerBand = indBuffer[0];

  CopyBuffer(handleWRP,0,0,1,indBuffer);      //WPR value
  currentWPR = indBuffer[0];

  //check if the spread allows trading 
  if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) <= PointDifferenceLimit){
    tradingAllowed = true;
  }
  else{
    tradingAllowed = false;
  }

  // stores the timestamp of the previous candle on the spacified timeframe 
  lastBarTime = iTime(_Symbol,PERIOD_M1,1);

  UpdatePosition();

  //lets calculate the compoundinterest if it is set to true 
  if(CompoundIntrestSwitch == true ){
    calculateLotSize = AccountInfoDouble(ACCOUNT_EQUITY) * Risk / accountBalanceDivisor;
    calculateLotSize = NormalizeDouble(calculateLotSize,2);
  }
  else{
    calculateLotSize = Lots; 
  }

  // get the broker time
  TimeCurrent(BrokerTime);
  TimeGMT(GMTTime);

  double Ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
  double Bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
  double point = _Point;

  if(MQLInfoInteger(MQL_TESTER) == true){
    
    if((BrokerTime.hour >= startTradingHour1 && BrokerTime.hour <= endTradingHour1) ||
      (BrokerTime.hour >= startTradingHour2 && BrokerTime.hour <= endTradingHour2)){
        
      if(upperBolligerBand - lowerBolllingerBand < maxBandWidth * point){
        if(upperBolligerBand - lowerBolllingerBand > minBandwidth * point){
          if(sellPositionCount + buyPositionCount < 1 && tradingAllowed == 1){

            //BUY LOGIC
            if(currentWPR < wprThreshold - 100 && lastSignalTime != lastBarTime){
              double margin;
              if(OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,calculateLotSize,Ask,margin) && 
                AccountInfoDouble(ACCOUNT_MARGIN_FREE) > margin){
                
                double sl = NormalizeDouble(Ask - stopLossPoints * point, _Digits);
                trade.Buy(calculateLotSize,_Symbol,Ask,sl,0,CommentName);
                lastSignalTime = lastBarTime;
                
              }
            }

            //SELL LOGIC
            if(currentWPR > -wprThreshold && lastSignalTime != lastBarTime){
              double margin;
              if(OrderCalcMargin(ORDER_TYPE_SELL,_Symbol,calculateLotSize,Bid,margin) && 
                AccountInfoDouble(ACCOUNT_MARGIN_FREE) > margin){
                
                double sl = NormalizeDouble(Bid + stopLossPoints * point, _Digits);
                trade.Sell(calculateLotSize,_Symbol,Bid,sl,0,CommentName);
                lastSignalTime = lastBarTime;
                
              }
            }
          }
        }
      }
    }
  }
  else{ // for a live account 
    if(GMTTime.hour >= 18 || GMTTime.hour <= 1){

      if(upperBolligerBand - lowerBolllingerBand < maxBandWidth * point){
        if(upperBolligerBand - lowerBolllingerBand > minBandwidth * point){
          if(sellPositionCount + buyPositionCount < 1 && tradingAllowed == 1){

            //BUY LOGIC
            if(currentWPR < wprThreshold - 100 && lastSignalTime != lastBarTime){
              double margin;
              if(OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,calculateLotSize,Ask,margin) && 
                AccountInfoDouble(ACCOUNT_MARGIN_FREE) > margin){
                
                double sl = NormalizeDouble(Ask - stopLossPoints * point, _Digits);
                trade.Buy(calculateLotSize,_Symbol,Ask,sl,0,CommentName);
                lastSignalTime = lastBarTime;
                
              }
            }

            //SELL LOGIC
            if(currentWPR > -wprThreshold && lastSignalTime != lastBarTime){
              double margin;
              if(OrderCalcMargin(ORDER_TYPE_SELL,_Symbol,calculateLotSize,Bid,margin) && 
                AccountInfoDouble(ACCOUNT_MARGIN_FREE) > margin){
                
                double sl = NormalizeDouble(Bid + stopLossPoints * point, _Digits);
                trade.Sell(calculateLotSize,_Symbol,Bid,sl,0,CommentName);
                lastSignalTime = lastBarTime;
                
              }
            }
          }
        }
      }
    }
  }
  // lets close buy trades if the WPR condition is met 
  if(buyPositionCount > 0 && tradingAllowed == 1 && currentWPR > (-wprThreshold)){
    for(int i =  PositionsTotal() - 1; i >= 0; --i){
      if(posinfo.SelectByTicket(i)){
        if(posinfo.Symbol() == _Symbol && posinfo.Magic() == Magic)
        if(posinfo.PositionType() == POSITION_TYPE_BUY)
          trade.PositionClose(posinfo.Ticket(),maxSlippage);
      }
    }
  }
  // lets close sell trades if the WPR conditions is met 
  if(sellPositionCount > 0 && tradingAllowed == 1 && currentWPR < (wprThreshold - 100)){
    for(int j =  PositionsTotal() - 1; j >= 0; --j){
      if(posinfo.SelectByTicket(j)){
        if(posinfo.Symbol() == _Symbol && posinfo.Magic() == Magic)
        if(posinfo.PositionType() == POSITION_TYPE_SELL)
          trade.PositionClose(posinfo.Ticket(),maxSlippage);
      }
    }
  }
  // close buy postions on take profit 
  if(buyPositionCount > 0 && tradingAllowed == 1 && (Bid - buyPrice) > (takeProfitPoints * point)){
    for(int k =  PositionsTotal() - 1; k >= 0; --k){
      if(posinfo.SelectByTicket(k)){
        if(posinfo.Symbol() == _Symbol && posinfo.Magic() == Magic)
        if(posinfo.PositionType() == POSITION_TYPE_BUY)
          trade.PositionClose(posinfo.Ticket(),maxSlippage);
      }
    }
  }
   // close sell postions on take profit 
  if(buyPositionCount > 0 && tradingAllowed == 1 && (sellPrice - Ask) > (takeProfitPoints * point)){
    for(int m =  PositionsTotal() - 1; m >= 0; --m){
      if(posinfo.SelectByTicket(m)){
        if(posinfo.Symbol() == _Symbol && posinfo.Magic() == Magic)
        if(posinfo.PositionType() == POSITION_TYPE_SELL)
          trade.PositionClose(posinfo.Ticket(),maxSlippage);
      }
    }
  } 

  // update display at the end
  UpdatePosition();
  UpdatePanelData();
  
}
 
//+------------------------------------------------------------------+
//| update position function                                         |
//+------------------------------------------------------------------+

int UpdatePosition(){
  //reset all counters 
  buyPositionCount  = 0;
  sellPositionCount = 0;
  totalBuyLots = 0;
  totalSellLots = 0;
  totalBuyProfit = 0;
  totalSellProfit = 0;
  buyPrice = 0;
  sellPrice = 0;
  buyStopLoss = 0;
  sellStopLoss = 0;

  // loop though all the open positions 
  for(int i = PositionsTotal() - 1; i >= 0 ; i--){
    posinfo.SelectByIndex(i);
    ulong ticket = posinfo.Ticket();
    if(posinfo.Symbol() == _Symbol && posinfo.Magic() == Magic){

      if(posinfo.PositionType() == POSITION_TYPE_SELL){
        ++sellPositionCount;
        double volume = posinfo.Volume();
        totalSellLots += volume;
        totalBuyProfit += posinfo.Profit() + posinfo.Commission() + posinfo.Swap();
        sellPrice = posinfo.PriceOpen();
        sellStopLoss = posinfo.StopLoss();
      }
      else if(posinfo.PositionType() == POSITION_TYPE_BUY){
        ++buyPositionCount;
        double volume = posinfo.Volume();
        totalSellLots += volume;
        totalBuyProfit += posinfo.Profit() + posinfo.Commission() + posinfo.Swap();
        sellPrice = posinfo.PriceOpen();
        sellStopLoss = posinfo.StopLoss();
      }
    }
  }

  return(0);
}

void CreateDisplayPanel(){
  // common settings 
  int panelX = 10;
  int panelY = 20;
  int panelWidth = 150;
  int panelHeight = 60;
  int spacing = 5;
  string fontName = "Arial";
  int fontSize = 10;

  // Create the first panel 
  ObjectCreate(0,"PositionPanel", OBJ_RECTANGLE_LABEL,0,0,0);
  ObjectSetInteger(0,"PositionPanel", OBJPROP_XDISTANCE,panelX);
  ObjectSetInteger(0,"PositionPanel", OBJPROP_XDISTANCE,panelY);
  ObjectSetInteger(0,"PositionPanel",OBJPROP_XSIZE,panelWidth);
  ObjectSetInteger(0,"PositionPanel", OBJPROP_YSIZE,panelHeight);
  ObjectSetInteger(0,"PositionPanel", OBJPROP_BGCOLOR,0x575757);
  ObjectSetInteger(0,"PositionPanel", OBJPROP_BORDER_TYPE,BORDER_FLAT);
  ObjectSetInteger(0,"PositionPanel", OBJPROP_BORDER_COLOR,clrGray);

  // sell positions 
  ObjectCreate(0,"SellLotsLabal", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"SellLotsLabal", OBJPROP_XDISTANCE,panelX + 10);
  ObjectSetInteger(0,"SellLotsLabal", OBJPROP_XDISTANCE,panelY + 10);
  ObjectSetString(0,"SellLotsLabal", OBJPROP_TEXT,"SellLots: 0");
  ObjectSetInteger(0,"SellLotsLabal", OBJPROP_COLOR,clrGoldenrod);
  ObjectSetInteger(0,"SellLotsLabal", OBJPROP_FONTSIZE,fontSize);

  //buy positions 
  ObjectCreate(0,"BuyLotsLabel", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"BuyLotsLabel", OBJPROP_XDISTANCE,panelX + 10);
  ObjectSetInteger(0,"BuyLotsLabel", OBJPROP_XDISTANCE,panelY + 30);
  ObjectSetString(0,"BuyLotsLabel", OBJPROP_TEXT,"BuyLots: 0");
  ObjectSetInteger(0,"BuyLotsLabel", OBJPROP_COLOR,clrGoldenrod);
  ObjectSetInteger(0,"BuyLotsLabel", OBJPROP_FONTSIZE,fontSize);


  // Create the Second panel 

  panelX += panelWidth + spacing;

  ObjectCreate(0,"profitPanel", OBJ_RECTANGLE_LABEL,0,0,0);
  ObjectSetInteger(0,"profitPanel", OBJPROP_XDISTANCE,panelX);
  ObjectSetInteger(0,"profitPanel", OBJPROP_XDISTANCE,panelY);
  ObjectSetInteger(0,"profitPanel",OBJPROP_XSIZE,panelWidth);
  ObjectSetInteger(0,"profitPanel", OBJPROP_YSIZE,panelHeight);
  ObjectSetInteger(0,"profitPanel", OBJPROP_BGCOLOR,0x575757);

  // sell profit - left label 
  ObjectCreate(0,"SellProfitLabel", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"SellProfitLabel", OBJPROP_XDISTANCE,panelX + 10);
  ObjectSetInteger(0,"SellProfitLabel", OBJPROP_XDISTANCE,panelY + 10);
  ObjectSetString(0,"SellProfitLabel", OBJPROP_TEXT,"SellProfit:");
  ObjectSetInteger(0,"SellProfitLabel", OBJPROP_COLOR,clrDeepSkyBlue);
  ObjectSetInteger(0,"SellProfitLabel", OBJPROP_FONTSIZE,fontSize);

  // sell profit - right label 
  ObjectCreate(0,"SellProfitValue", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"SellProfitValue", OBJPROP_XDISTANCE,panelX + panelWidth - 10);
  ObjectSetInteger(0,"SellProfitValue", OBJPROP_XDISTANCE,panelY + 20);
  ObjectSetString(0,"SellProfitValue", OBJPROP_TEXT,".0.00");
  ObjectSetInteger(0,"SellProfitValue", OBJPROP_COLOR,clrLime);
  ObjectSetInteger(0,"SellProfitValue", OBJPROP_FONTSIZE,fontSize);
  ObjectSetInteger(0,"SellProfitValue", OBJPROP_ANCHOR,ANCHOR_RIGHT);

   // buy profit - left label 
  ObjectCreate(0,"BuyProfitLabel", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"BuyProfitLabel", OBJPROP_XDISTANCE,panelX + 10);
  ObjectSetInteger(0,"BuyProfitLabel", OBJPROP_XDISTANCE,panelY + 30);
  ObjectSetString(0,"BuyProfitLabel", OBJPROP_TEXT,"BuyProfit:");
  ObjectSetInteger(0,"BuyProfitLabel", OBJPROP_COLOR,clrDeepSkyBlue);
  ObjectSetInteger(0,"BuyProfitLabel", OBJPROP_FONTSIZE,fontSize);

  // buy profit - right label 
  ObjectCreate(0,"BuyProfitValue", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"BuyProfitValue", OBJPROP_XDISTANCE,panelX + panelWidth - 10);
  ObjectSetInteger(0,"BuyProfitValue", OBJPROP_XDISTANCE,panelY + 40);
  ObjectSetString(0,"BuyProfitValue", OBJPROP_TEXT,".0.00");
  ObjectSetInteger(0,"BuyProfitValue", OBJPROP_COLOR,clrLime);
  ObjectSetInteger(0,"BuyProfitValue", OBJPROP_FONTSIZE,fontSize);
  ObjectSetInteger(0,"BuyProfitValue", OBJPROP_ANCHOR,ANCHOR_RIGHT);


  // Create the Spread panel 

  panelX += panelWidth + spacing;

  ObjectCreate(0,"spreadPanel", OBJ_RECTANGLE_LABEL,0,0,0);
  ObjectSetInteger(0,"spreadPanel", OBJPROP_XDISTANCE,panelX);
  ObjectSetInteger(0,"spreadPanel", OBJPROP_XDISTANCE,panelY);
  ObjectSetInteger(0,"spreadPanel",OBJPROP_XSIZE,panelWidth);
  ObjectSetInteger(0,"spreadPanel", OBJPROP_YSIZE,panelHeight);
  ObjectSetInteger(0,"spreadPanel", OBJPROP_BGCOLOR,0x575757);


  // spread labal (Red)
  ObjectCreate(0,"spreadLabal", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"spreadLabal", OBJPROP_XDISTANCE,panelX + 10);
  ObjectSetInteger(0,"spreadLabal", OBJPROP_XDISTANCE,panelY + 10);
  ObjectSetString(0,"spreadLabal", OBJPROP_TEXT,"Spread");
  ObjectSetInteger(0,"spreadLabal", OBJPROP_COLOR,clrRed);
  ObjectSetInteger(0,"spreadLabal", OBJPROP_FONTSIZE,fontSize);

  //Spread labal (white)
  ObjectCreate(0,"spreadValue", OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,"spreadValue", OBJPROP_XDISTANCE,panelX + 10);
  ObjectSetInteger(0,"spreadValue", OBJPROP_XDISTANCE,panelY + 30);
  ObjectSetString(0,"spreadValue", OBJPROP_TEXT,(string)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD));
  ObjectSetInteger(0,"spreadValue", OBJPROP_COLOR,clrWhite);
  ObjectSetInteger(0,"spreadValue", OBJPROP_FONTSIZE,fontSize);
}

void UpdatePanelData(){
  double totalBuylots = 0;
  double totalSelllots = 0;
  
  // calculate opened lots
  for(int i = PositionsTotal() - 1; i >= 0; i--){
    posinfo.SelectByTicket(i);

    if(posinfo.Symbol() == Symbol() && posinfo.Magic() == Magic){
      if(posinfo.PositionType() == POSITION_TYPE_BUY)
        totalBuyLots += posinfo.Volume();

      if(posinfo.PositionType() == POSITION_TYPE_SELL)
        totalSellLots += posinfo.Volume();
    }

  }

  //update position lots display 
  ObjectSetString(0,"SellLotsLabel", OBJPROP_TEXT,"SellLots:" + DoubleToString(totalSelllots,2));
  ObjectSetString(0,"BuyLotsLabel", OBJPROP_TEXT,"BuyLots:" + DoubleToString(totalBuylots,2));

  // update profits(existing code)
  UpdateProfitDisplay("SellProfitValue",totalSellProfit);
  UpdateProfitDisplay("BuyProfitValue",totalBuyProfit);

  // update spread
  ObjectSetString(0,"SpreadValue", OBJPROP_TEXT,(string)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD));

}

void UpdateProfitDisplay(string objName, double profit){
  color textColor = profit >= 0 ? clrLime : clrRed;
  string text = DoubleToString(profit,2);

  ObjectSetString(0,objName,OBJPROP_NAME, text);
  ObjectSetInteger(0,objName,OBJPROP_COLOR, textColor);

}