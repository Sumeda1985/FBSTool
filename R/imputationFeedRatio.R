imputationFeedRatio=function(input,output,session){
  
  show_modal_spinner(
    
    spin = "cube-grid",
    color = "firebrick",
    text = "Please wait...",
    session = shiny::getDefaultReactiveDomain()
  )
  
  t=as.numeric(as.numeric(input$fromyear) : as.numeric(input$endyear))
  

 # data <-  data.table(read_excel("Data/feedRatio.xlsx")) 
  
  data <- data.table(df_feed_ratio$data_feed_ratio)
  
 data <- long_format(data)
 
 data[!is.na(Value) & is.na(Flag), Flag := ""]
 


 data[is.na(Value) & Flag == "", Flag := NA_character_ ]


 
 
for (j in seq(t)){
  
 
  data_feed_Ratio <- list() 
  
  data_feed_Ratio[[j]] <- subset(data , Year %in% c(2010 :t[j]))
  

  data_feed_Ratio[[j]][ , new_value := ifelse(Year == t[j] & !Flag %in%  c("", "T","E"), NA, Value)]
  data_feed_Ratio[[j]][ , Value := ifelse(Year == t[j] & !Flag %in%  c("", "T","E"), NA, Value)]
  
  data_feed_Ratio[[j]][ , new_flag := ifelse(Year == t[j] & !Flag %in%  c("", "T","E"), NA, Flag)]
  data_feed_Ratio[[j]][ , Flag := ifelse(Year == t[j] & !Flag %in%  c("", "T","E"), NA, Flag)]
  
  data_feed_Ratio[[j]] <-
    data_feed_Ratio[[j]] %>%
    group_by(CPCCode) %>%
    arrange(CPCCode) %>%
    tidyr::fill(new_value, new_flag, .direction = "down") %>%
    # tidyr::fill(Value, flagObservationStatus, flagMethod, .direction = "down") %>%
    setDT()
  
  
  
  data_feed_Ratio[[j]][is.na(Value), Value := new_value]
  data_feed_Ratio[[j]][is.na(Flag), Flag := new_flag]
  
  data_feed_Ratio[[j]][, c("new_value","new_flag") := NULL]
  
  new_data <- rbindlist(data_feed_Ratio)
  
  data <- data[!Year %in% c(2010:t[j])]
  
  data <- rbind(data,new_data)
  
  data <-  data[order(CPCCode, Year)]
  

  
}
 
 
 data <- wide_format(data)
 
 Sys.sleep(3)
 remove_modal_spinner()
 
 observeEvent(input$feed_imputation_ratio,{
   sendSweetAlert(
     session = session,
     title = "Imputed !!",
     text = "Missing values have been imputed successfully. Please refer to the manual for the methodology applied.",
     type = "success"
   )
   
 })
 
 return(data)
 
}
 
 
   
