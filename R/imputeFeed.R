imputeFeed=function(input,output,session){

#Feed Module only imputes values for NA in the year t. Official data are c(2010:t) or Flag %in% c("", T). If you have a figure with flag I,
#in t, then it will not be touched. Only touched if NA in year t. 
  show_modal_spinner(
    
    spin = "cube-grid",
    color = "firebrick",
    text = "Please wait...",
    session = shiny::getDefaultReactiveDomain()
  )
  
  
  t=as.numeric(as.numeric(input$fromyear) : as.numeric(input$endyear))
  
  data_Session <- data.table(df_sua_unbalanced$data_sua_unbalanced )
  
  data_Session <- long_format(data_Session)
  
  
  # data_Session <- copy(countryData)
  # data_Session[,c("CountryM49","Country"):=NULL]
  
  
  if (unique(countryData$CountryM49) %in% "835"){
    
    itemFeed <- data.table(read_excel("Data/feedRatio.xlsx"))
    
    itemFeed=unique(itemFeed[,c("CPCCode", "Commodity")])
    
    itemFeed_session=subset(data_Session, ElementCode == "5520")
    itemFeed_session <- unique(itemFeed_session[,c("CPCCode","Commodity")])
    
    itemFeed <- rbind(itemFeed,itemFeed_session)
    itemFeed <-itemFeed[!duplicated(itemFeed[,"CPCCode"])]
    
  }else {
    
    # itemFeed=subset(data_Session, ElementCode == "5520")
    
    itemFeed_session=subset(data_Session, ElementCode == "5520")
    itemFeed_session <- unique(itemFeed_session[,c("CPCCode","Commodity")])
    
    
    itemFeed <- data.table(read_excel("Data/feedRatio.xlsx"))
    itemFeed=unique(itemFeed[,c("CPCCode", "Commodity")])
    
    itemFeed <- rbind(itemFeed,itemFeed_session)
    itemFeed <-itemFeed[!duplicated(itemFeed[,"CPCCode"])]
  }
  

  # upload feed ratios
  ratios <- read_excel("Data/feedRatio.xlsx")
  setDT(ratios)
  
  
  
  ratios <- long_format(ratios)
  # ratios[, Value := round(Value,0)]
  
  
  
  ratios$Flag =ifelse(!is.na(ratios$Value) & is.na(ratios$Flag), "", ratios$Flag)
  setnames(ratios,"Flag","[Ratio] Flag")
  
  ratios$`ElementCode`= NULL
  ratios$Element = NULL
  # ratios$`[Ratio] Flag` = ""
  
  setnames(ratios,c("Value"),c("Ratios [%]"))
  
  
  #Uplaod Trade Data
  
  tradeData=subset(data_Session , ElementCode %in% c("5610", "5910"))
  
  
  tradeData=tradeData[Year %in% c(2010:t[length(t)])]
  # tradeData[,HS6 :=NULL]
  
 
  #Filter Trade Data for itemFeed
  # tradeData <-tradeData[CPCCode %in% itemFeed$CPCCode]
  
  importData = subset(tradeData, ElementCode == 5610 & CPCCode %in% itemFeed$CPCCode)
  
  importData[, c("ElementCode","Element") := NULL]
  
  
  
  
  
  # importData = filter(tradeData, ElementCode == 5610)
  # importData$ElementCode = NULL
  # importData$Element = NULL
  setnames(importData,"Value","[5610] Import Quantity [t]")
  setnames(importData,"Flag","[5610] Flag")
  
  importData$`[5610] Flag` =ifelse(!is.na(importData$`[5610] Import Quantity [t]`) & is.na(importData$`[5610] Flag`), "", importData$`[5610] Flag`)
  
  # importData[, `[5610] Flag` := ifelse(!is.na(`[5610] Import Quantity [t]`) ,"",`[5610] Flag`)]
  
  
  
  
  
  exportData = subset(tradeData, ElementCode == 5910 & CPCCode %in% itemFeed$CPCCode)
  
  exportData[, c("ElementCode","Element") := NULL]
  # exportData$ElementCode = NULL
  # exportData$Element = NULL
  setnames(exportData,"Value","[5910] Export Quantity [t]")
  setnames(exportData,"Flag","[5910] Flag")
  
  exportData$`[5910] Flag` =ifelse(!is.na(exportData$`[5910] Export Quantity [t]`) & is.na(exportData$`[5910] Flag`) , "", exportData$`[5910] Flag`)
  
  # upload feed data
  feedData = subset(data_Session, ElementCode == 5520 & CPCCode %in% itemFeed$CPCCode)
  setDT(feedData)
  
  feedData[is.na(Value), Flag := NA ]
  
  
  
  feedData[, c("ElementCode","Element") := NULL]
  
  # feedData$ElementCode = NULL
  # feedData$Element = NULL
  setnames(feedData,"Value","[5520] Feed [t]")
  setnames(feedData,"Flag","[5520] Flag")
  
  
  feedData$`[5520] Flag` =ifelse(!is.na(feedData$`[5520] Feed [t]`) & is.na(feedData$`[5520] Flag`), "", feedData$`[5520] Flag`)
  

  # upload production data
  productionData=subset(data_Session, ElementCode == "5510")
  
  productionData[, c("ElementCode","Element") := NULL] 
  
  
  productionData = subset(productionData, (CPCCode %in% itemFeed$CPCCode))
  
  # productionData$ElementCode = NULL
  # productionData$Element = NULL
  setnames(productionData,"Value","[5510] Production [t]")
  setnames(productionData,"Flag","[5510] Flag")
  
  
  productionData$`[5510] Flag` =ifelse(!is.na(productionData$`[5510] Production [t]`) & is.na(productionData$`[5510] Flag`), "", productionData$`[5510] Flag`)
  

  
  
########### Data Merging   
  
  data = merge(feedData[,-c("Commodity")],productionData[,-c("Commodity")],
               by = c( "CPCCode","Year"),
               all = TRUE)
  
  
  
  data = merge(data,importData[,-c("Commodity")],
               by = c( "CPCCode","Year"),
               all = TRUE)
  
  data = merge(data,exportData[,-c("Commodity")],
               by = c( "CPCCode","Year"),
               all = TRUE)
  
 
  #
  setDT(data)
  

  
  data = merge(data,ratios[,-c("Commodity")],
               by = c("CPCCode","Year"),
               all.x  = TRUE)
  
  
  
  data[, Protected := ifelse(!is.na(`[5520] Feed [t]`) & `[5520] Flag` %in% c("","T","E"), TRUE, FALSE)] 
  
  ProdNT = c()
  for(i in 1:dim(data)[1]){
    ProdNT[i] = sum(data[i,]$'[5510] Production [t]',
                    data[i,]$'[5610] Import Quantity [t]', 
                    - data[i,]$'[5910] Export Quantity [t]',na.rm = TRUE)
  }
  
  data$ProdNT = ProdNT
  data$`[ProdNT] Flag` = "I"
  
  
  data <- merge(data,all_cpc, by = "CPCCode" , all.x = TRUE)
  
  
  for (j in t){
    
   
    officialData = filter(data, Year %in% c(2010:(j-1)))
    
    
    # ProdNT = c()
    # for(i in 1:dim(officialData)[1]){
    #   ProdNT[i] = sum(officialData[i,]$'[5510] Production [t]',
    #                   officialData[i,]$'[5610] Import Quantity [t]', 
    #                   - officialData[i,]$'[5910] Export Quantity [t]',na.rm = TRUE)
    # }
    # 
    # officialData$ProdNT = ProdNT
    # officialData$`[ProdNT] Flag` = "I"
    
     
    #changed here
    officialData$`Ratios [%]` = ifelse(is.na(officialData$`[Ratio] Flag`) & officialData$ProdNT != 0, 
                                       (officialData$'[5520] Feed [t]'/officialData$ProdNT)*100, officialData$`Ratios [%]`)
    
    
    officialData$`Ratios [%]` = round(officialData$`Ratios [%]`,0)
    officialData$`[Ratio] Flag` = ifelse(is.na(officialData$`[Ratio] Flag`) & !is.na(officialData$`Ratios [%]`), "I",officialData$`[Ratio] Flag`)
    
    
    calcRatios = aggregate(`Ratios [%]` ~ CPCCode,data = officialData,mean)
    calcRatios$`Ratios [%]` = round(calcRatios$`Ratios [%]`,0)
    
    calcRatios$`Ratios [%]` = ifelse(calcRatios$`Ratios [%]` < 0, 0 , calcRatios$`Ratios [%]`)
    # calcRatios$`Ratios [%]` = ifelse(calcRatios$`Ratios [%]` == "Inf", 0, calcRatios$`Ratios [%]`)
    #
    
    setnames(calcRatios,"Ratios [%]","Ratios ReCalculated")
    
    imputedData = filter(data, Year %in% c(j) )
    
    imputedData = merge(imputedData,calcRatios,
                        by = "CPCCode",
                        all.x = TRUE)
    
    
    
    imputedData$`Ratios [%]` = ifelse(is.na(imputedData$`Ratios [%]`) 
                                      ,imputedData$`Ratios ReCalculated`,imputedData$`Ratios [%]`)
    
    
    imputedData$`[Ratio] Flag` = ifelse(!imputedData$`[Ratio] Flag` %in% c("","T","E") & !is.na(imputedData$`Ratios [%]`), 
                                        "I", imputedData$`[Ratio] Flag`)
    # imputedData$`[Ratio] Flag` = ifelse(!is.na(imputedData$`Ratios [%]`), "I", NA)
    
    imputedData$`Ratios ReCalculated` = NULL
    
    
    
    # prodNT = c()
    # for(i in 1:dim(imputedData)[1]){
    #   prodNT[i] = sum(imputedData[i,]$'[5510] Production [t]',
    #                   imputedData[i,]$'[5610] Import Quantity [t]', 
    #                   - imputedData[i,]$'[5910] Export Quantity [t]',na.rm = TRUE)
    # }
    # 
    # imputedData$ProdNT = prodNT
    # imputedData$`[ProdNT] Flag` = "I"
    
    setDT(imputedData)
    
    imputedData[, Protected := ifelse( !`[5520] Flag` %in% c("","T","E") , FALSE, TRUE)]
    
    
    imputedData[, new_feed :=`Ratios [%]`*ProdNT/100, by= 1: nrow(imputedData) ]
    
    
    
    # imputedData$`[5520] Feed [t]` = ifelse(is.na(imputedData$`[5520] Flag`), 
    #                                        (imputedData$`Ratios [%]`*imputedData$ProdNT)/100, imputedData$`[5520] Feed [t]`)
    #
    
    
    imputedData[Protected == FALSE, `[5520] Feed [t]` := new_feed]
    
    
    imputedData[Protected == FALSE & !is.na(`[5520] Feed [t]`), `[5520] Flag` := "I"]
    
    
    imputedData[, c("Protected","new_feed") :=NULL]
    
    imputedData[,`[5520] Feed [t]` := round(`[5520] Feed [t]`,0)]
    
    
    # setcolorder(imputedData,names(officialData))
    
    imputedData=imputedData[!is.na(`[5520] Feed [t]`)]
    
    imputedData <- imputedData[,c("CPCCode", "Year", "[5520] Feed [t]", "[5520] Flag")]
    
    
    # officialData$`Ratios [%]` = ifelse(officialData$`Ratios [%]` < 0, 0 , officialData$`Ratios [%]`)
    
    
    data <- merge(data, imputedData, by = c("CPCCode","Year"), all.x = TRUE)
    
    data[, `[5520] Feed [t].x`:= ifelse(Protected == F & Year == j,`[5520] Feed [t].y`,`[5520] Feed [t].x`)]
    
    data[, `[5520] Flag.x`:= ifelse(Protected == F & Year == j,`[5520] Flag.y`,`[5520] Flag.x`)]
    
    data[,c("[5520] Feed [t].y","[5520] Flag.y"):= NULL]
    
    setnames(data,c("[5520] Feed [t].x","[5520] Flag.x"),c("[5520] Feed [t]","[5520] Flag"))
    
  }
  
  
  finalFeedData <- copy(data)
  
  finalFeedData <- finalFeedData[!is.na(`[5520] Feed [t]`)]
  
  finalFeedData$`Ratios [%]` = as.numeric(finalFeedData$`Ratios [%]`)
  finalFeedData$`[5610] Import Quantity [t]` = as.numeric(finalFeedData$`[5610] Import Quantity [t]`)
  finalFeedData$`[5910] Export Quantity [t]` = as.numeric(finalFeedData$`[5910] Export Quantity [t]`)
  
  finalFeedData[, Protected := NULL]
  
  #
 
  
  # # # Recalculate the Loss Ratio
  # finalFeedData$`Ratios ReCalculated [%]` = round(finalFeedData$`[5520] Feed [t]`/finalFeedData$ProdNT*100,0)
  # finalFeedData[!is.na(finalFeedData$`Ratios ReCalculated [%]`), `[ReCalulated Ratio] Flag` := "I"]
  
  # finalFeedData[, sum(`[5520] Feed [t]`,na.rm = TRUE), by = Year]
  # 7,9,11,13,15,17,19
  
  feedValueData = melt(finalFeedData[,-c("[5610] Flag","[5910] Flag","[5510] Flag","[5520] Flag","[Ratio] Flag","[ProdNT] Flag")], 
                 id.vars = c("CPCCode","Commodity","Year"),
                       variable.name = "Element", value.name = "Value")
  
  
  feedValueData$Element = ifelse(feedValueData$Element == "[5520] Feed [t]","Feed [t]",
                                 ifelse(feedValueData$Element == "[5510] Production [t]","Production [t]",
                                        ifelse(feedValueData$Element == "[5610] Import Quantity [t]","Import Quantity [t]",
                                               ifelse(feedValueData$Element == "[5910] Export Quantity [t]","Export Quantity [t]",
                                                      ifelse(feedValueData$Element == "ProdNT","ProdNT [t]",
                                                             "Ratios [%]"
                                                                    )))))
  
  
  # 6,8,10,12,14,16,18
  
  feedFlagData = melt(finalFeedData[,-c("[5610] Import Quantity [t]","[5910] Export Quantity [t]","[5510] Production [t]",
                                        "[5520] Feed [t]","Ratios [%]","ProdNT")],
                      id.vars = c("CPCCode","Commodity","Year"),
                      variable.name = "Flag Description", value.name = "Flag")
  
  
  feedFlagData$`Flag Description` = NULL
  
  # finalseedData
  finalFeedData = cbind(feedValueData,feedFlagData[,"Flag"])
  finalFeedData$ElementCode = ifelse(feedValueData$Element == "Feed [t]","5520",
                                     ifelse(feedValueData$Element == "Production [t]","5510",
                                            ifelse(feedValueData$Element == "Import Quantity [t]","5610",
                                                   ifelse(feedValueData$Element == "Export Quantity [t]","5910",
                                                          ifelse(feedValueData$Element == "ProdNT","xxxx",
                                                                 "xxxx"
                                                                        )))))
  
  finalFeedData = setcolorder(finalFeedData, c("CPCCode","Commodity","ElementCode","Element","Year","Value","Flag"))
  finalFeedData = finalFeedData[order(CPCCode,Year)]
  
  
  
  finalFeedData[, Value := ifelse(ElementCode =="5520" & Value< 0 , NA, Value)]
  
  finalFeedData <-  finalFeedData[ElementCode == "5520" & is.na(Value), Flag := NA]
  
  finalFeedData <- finalFeedData[!duplicated(finalFeedData[,c("CPCCode","Element","Year")])]
  
  
  finalFeedData[, Value := ifelse(Value == Inf, NA, Value)]
  
  finalFeedData[, Flag := ifelse(is.na(Value), NA, Flag)]
  
  finalFeedData
  
  Sys.sleep(3)
  remove_modal_spinner()
 #for some t values feed is not imputed because ratio is missing and also the prodNT is zero.  
  
  observeEvent(input$feed_imputation,{
    sendSweetAlert(
      session = session,
      title = "Imputed !!",
      text = "Missing values have been imputed successfully. Please refer to the manual for the methodology applied.",
      type = "success"
    )
    
  })
  
  
# write.csv(finalFeedData,file = "Feed/Data/finalFeedData.csv", row.names = FALSE)
  


return(finalFeedData)
  
  
}