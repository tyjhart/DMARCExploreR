library(xml2)
library(lubridate)
library(tidyverse)
library(arrow)
library(rlog)
library(R.utils)

#!/usr/bin/env Rscript
args = commandArgs(asValues=TRUE)

# Logging options ####
if (!is.null(args$LogLevel)) {
  DebugLevel <- args$LogLevel
} else {
  DebugLevel <- "INFO"
}

LogSeparator <- "============================================"

# Set the debug level
Sys.setenv("LOG_LEVEL" = DebugLevel)
rlog::log_info(LogSeparator)
rlog::log_info(paste("Set log level to", DebugLevel, sep = " "))

# Import XML files ####
rlog::log_info("Getting list of XML files")
files <- list.files(path = "../Reports/", pattern = "\\.xml$", recursive = TRUE, full.names = TRUE)
rlog::log_info(paste("Found", length(files), "XML files", sep = " "))

# Quit if no new files
if(length(files) == 0) {
  rlog::log_info("No new XML files, quitting.")
  rlog::log_info(LogSeparator)
  quit(status = 20, save = "no")
}

rlog::log_debug(files)

# Master record data frame ####
df.Records <- data.frame(
  'Report_File_Name' = character(),
  'Domain' = character(),
  'Report_ID' = character(),
  'Org_Name' = character(),
  'Date_Range_Begin' = character(),
  'Date_Range_End' = character(),
  'Source_IP' = character(),
  'Count' = character(),
  'Header_From' = character(),
  'Envelope_To' = character(),
  'Envelope_From' = character(),
  'Policy_Eval_Disposition' = character(),
  'Policy_Eval_DKIM' = character(),
  'Policy_Eval_SPF' = character(),
  'Auth_Results' = character(),
  stringsAsFactors = FALSE)

# Master policy data frame ####
df.Policies <- data.frame(
  'Report_ID' = character(),
  'Domain' = character(),
  'ADKIM' = character(),
  'ASPF' = character(),
  'Policy' = character(),
  'Subdomain_Policy' = character(),
  'Percent' = character(),
  'Failure_Reporting_Options' = character(),
  'Date_Range_Begin' = character(),
  'Date_Range_End' = character(),
  stringsAsFactors = FALSE)

### Parse each XML file ###
rlog::log_info("Iterating through XML files")

# Logging for bad reports
BadReports <- 0
BadReportFiles <- c()

# Iterate through files
for (report in files) {
  rlog::log_debug(report)
  tryCatch(                       # Applying tryCatch
    expr = {
      # Read the whole, raw XML document
      RawXML <- read_xml(report)
      
      ### Extract report parts ###
      # Report metadata
      ReportSummary <- as_list(xml_find_all(RawXML, "//report_metadata"))[[1]]
      
      # Policy details
      Policy <- as_list(xml_find_all(RawXML, "//policy_published"))[[1]]
      
      ### Parse report parts ###
      # Date range
      # Beginning
      if(length(ReportSummary$date_range$begin)) {
        Date_Range_Begin <- ReportSummary$date_range$begin[[1]]
      } else if(length(ReportSummary$data_range$begin)) {
        # Reports from KDDI sometimes have data_range instead of date_range
        Date_Range_Begin <- ReportSummary$data_range$begin[[1]]
      }
      
      # End
      if(length(ReportSummary$date_range$end)) {
        Date_Range_End <- ReportSummary$date_range$end[[1]]
      } else if(length(ReportSummary$data_range$end)) {
        # Reports from KDDI sometimes have data_range instead of date_range
        Date_Range_End <- ReportSummary$data_range$end[[1]]
      }
      
      # Policies
      PolicyList <- list(
        'Report_ID' = NA,
        'Domain' = NA,
        'ADKIM' = NA,
        'ASPF' = NA,
        'Policy' = NA,
        'Subdomain_Policy' = NA,
        'Percent' = NA,
        'Failure_Reporting_Options' = NA,
        'Date_Range_Begin' = Date_Range_Begin,
        'Date_Range_End' = Date_Range_End
      )
      
      PolicyList$Report_ID <- ReportSummary$report_id[[1]]
      PolicyList$Domain <- Policy$domain[[1]]
      
      ### DKIM Identifier Alignment mode (adkim) ###
      # This is optional in DMARC RFC, assumed to be "r" if absent
      if(!is.null(Policy$adkim[[1]])) {
        PolicyList$ADKIM <- Policy$adkim[[1]]
        rlog::log_debug(paste("Policy$adkim[[1]]:", Policy$adkim[[1]], sep = " "))
      } else {
        # RFC default
        PolicyList$ADKIM <- "r"
        rlog::log_debug("Using default RFC PolicyList$ADKIM")
      }
      
      ### SPF Identifier Alignment mode (aspf) ###
      # This is optional in DMARC RFC, assumed to be "r" if absent
      if(!is.null(Policy$aspf[[1]])) {
        PolicyList$ASPF <- Policy$aspf[[1]]
        rlog::log_debug(paste("Policy$aspf[[1]]:", Policy$aspf[[1]], sep = " "))
      } else {
        # RFC default
        PolicyList$ASPF <- "r"
        rlog::log_debug("Using default RFC PolicyList$ASPF")
      }
      
      # Policy (p)
      PolicyList$Policy <- Policy$p[[1]]
      rlog::log_debug(paste("Policy$p[[1]]:", Policy$p[[1]], sep = " "))
      
      # Subdomain Policy (sp)
      if(!is.null(Policy$sp[[1]])) {
        PolicyList$Subdomain_Policy <- Policy$sp[[1]]
        rlog::log_debug(paste("Policy$sp[[1]]:", Policy$sp[[1]], sep = " "))
      }
      
      # Percentage of messages (pct)
      if(!is.null(Policy$pct[[1]])) {
        PolicyList$Percent <- Policy$pct[[1]]
        rlog::log_debug(paste("Policy$pct[[1]]:", Policy$pct[[1]], sep = " "))
      } else {
        # RFC default
        PolicyList$Percent <- "100"
        rlog::log_debug("Using default RFC Policy$pct")
      }
      
      # Failure Reporting Options (fo)
      if(!is.null(Policy$fo[[1]])) {
        PolicyList$Failure_Reporting_Options <- Policy$fo[[1]]
      } else {
        # RFC default
        PolicyList$Failure_Reporting_Options <- "0"
      }
      
      # Add policy to master DF
      df.Policies <- rbind(PolicyList, df.Policies, stringsAsFactors = FALSE)
      
      # Records
      Records <- as_list(xml_find_all(RawXML, "//record"))
      
      for (record in Records) {
        
        # Temp record storage
        RecordList <- list(
          Report_File_Name = NA,
          Domain = NA,
          Report_ID = NA,
          Org_Name = NA,
          #Date_Range_Begin = NA,
          #Date_Range_End = NA,
          Source_IP = NA,
          Count = NA,
          Header_From = NA,
          Envelope_To = NA,
          Envelope_From = NA,
          Policy_Eval_Disposition = NA,
          Policy_Eval_DKIM = NA,
          Policy_Eval_SPF = NA,
          Auth_Results = NA
        )
        
        RecordList$Report_File_Name <- report
        RecordList$Domain <- Policy$domain[[1]]
        RecordList$Report_ID <- ReportSummary$report_id[[1]]
        RecordList$Org_Name <- ReportSummary$org_name[[1]]
        #RecordList$Date_Range_Begin <- ReportSummary$date_range$begin[[1]]
        #RecordList$Date_Range_End <- ReportSummary$date_range$end[[1]]
        RecordList$Source_IP <- record$row$source_ip[[1]]
        RecordList$Count <- record$row$count[[1]]
        
        if(lengths(record$identifiers$header_from[[1]])) {
          RecordList$Header_From <- record$identifiers$header_from[[1]]
        } 
        
        if(length(record$identifiers$envelope_from) > 0) {
          RecordList$Envelope_From <- record$identifiers$envelope_from[[1]]
        }
        
        if(length(record$identifiers$envelope_to) > 0) {
          RecordList$Envelope_To <- record$identifiers$envelope_to[[1]]
        }
        
        ### Policy Evaluated ###
        RecordList$Policy_Eval_Disposition <- record$row$policy_evaluated$disposition[[1]]
        
        if(lengths(record$row$policy_evaluated$dkim[[1]])) {
          RecordList$Policy_Eval_DKIM <- record$row$policy_evaluated$dkim[[1]]
        } 
        
        if (lengths(record$row$policy_evaluated$spf[[1]])) {
          RecordList$Policy_Eval_SPF <- record$row$policy_evaluated$spf[[1]]
        }
        
        ### Auth_Results ###
        auth_result_c <- c()
        for (auth_result_i in 1:length(record$auth_results)) {
          auth_record_type <- paste("type",names(record$auth_results[auth_result_i]), sep = "=")
          auth_record <- paste(names(record$auth_results[[auth_result_i]]), unlist(record$auth_results[[auth_result_i]]),sep="=",collapse="," )
          auth_result_c <- append(auth_result_c, paste0(paste(auth_record_type,auth_record, sep = ","),";"))
        }
        RecordList$Auth_Results <- paste(auth_result_c, collapse = '') 
        
        # Append dates
        RecordList$Date_Range_Begin <- Date_Range_Begin
        RecordList$Date_Range_End <- Date_Range_End
        
        # Add record to master DF
        df.Records <- rbind(RecordList, df.Records)
      }
      
    },
    
    error = function(e){          # Specifying error message
      rlog::log_error(paste("ERROR PARSING XML:", report, sep = " "))
      BadReports <- BadReports + 1
      BadReportFiles <- append(BadReportFiles, report)
    },
    
    warning = function(w){        # Specifying warning message
      rlog::log_warn(paste("WARNING PARSING XML:", report, sep = " "))
      BadReports <- BadReports + 1
      BadReportFiles <- append(BadReportFiles, report)
    },
    
    finally = {                   # Specifying final message
      rlog::log_debug(paste("Completed parsing XML. Bad reports:", BadReports, sep = " "))
    }
  )
}

if(BadReports > 0) {
  rlog::log_warn(paste("Bad report names:", BadReportFiles, sep = " "))
}

# Convert epoch timestamps ####
rlog::log_info("Formatting timestamps")
# Policies
df.Policies$Date_Range_Begin <- as.Date(as_datetime(as.numeric(df.Policies$Date_Range_Begin)))
df.Policies$Date_Range_End <- as.Date(as_datetime(as.numeric(df.Policies$Date_Range_End)))

# Records
df.Records$Date_Range_Begin <- as.Date(as_datetime(as.numeric(df.Records$Date_Range_Begin)))
df.Records$Date_Range_End <- as.Date(as_datetime(as.numeric(df.Records$Date_Range_End)))
rlog::log_info("Timestamps done")

# Email counts ####
df.Records$Count <- as.integer(df.Records$Count)

# Case ####
# Decisions
df.Records$Policy_Eval_Disposition <- str_to_title(df.Records$Policy_Eval_Disposition)
df.Records$Policy_Eval_DKIM <- str_to_title(df.Records$Policy_Eval_DKIM)
df.Records$Policy_Eval_SPF <- str_to_title(df.Records$Policy_Eval_SPF)

# Domains, To, From ####
df.Records$Domain <- tolower(df.Records$Domain)
df.Records$Header_From <- tolower(df.Records$Header_From)
df.Records$Envelope_To <- tolower(df.Records$Envelope_To)

# Envelope_To #### 
if(sum(is.na(df.Records$Envelope_To)) > 0) {
  df.Records[which(is.na(df.Records$Envelope_To)),]$Envelope_To <- "Not Reported"
}

df.Records$Envelope_From <- tolower(df.Records$Envelope_From)

# Factorize ####
rlog::log_info("Factorizing...")
df.Records$Org_Name <- as.factor(df.Records$Org_Name)
df.Records$Header_From <- as.factor(df.Records$Header_From)
df.Records$Policy_Eval_Disposition <- as.factor(df.Records$Policy_Eval_Disposition)
df.Records$Policy_Eval_DKIM <- as.factor(df.Records$Policy_Eval_DKIM)
df.Records$Policy_Eval_SPF <- as.factor(df.Records$Policy_Eval_SPF)
rlog::log_info("Completed factorizing")

# Write Parquet file ####
# All records
rlog::log_info("Writing all records Parquet")
ParquetPath <- paste0("../Parquet/",format(Sys.time(), "%Y-%m-%d-%H-%M-%S"),".parquet")
write_parquet(df.Records, ParquetPath, compression = "gzip")

# Write Tab-Separated file ####
# UNCOMMENT THESE LINES FOR A TAB-SEPARATED TXT EXPORT
#TabFilePath <- paste0("../",format(Sys.time(), "%Y-%m-%d-%H-%M-%S"),".txt")
#write.table(df.Records, TabFilePath, row.names = FALSE, sep = "\t")

# Quit ####
rlog::log_info("Rscript completed parsing records.")
rlog::log_info(LogSeparator)
