#' Dieses R Skript untersucht die Sendungen ZDF Heute, ZDF Heute Journal und 
#' ARD Tagesschau nach Frames, welche nicht im Internet verfügbar sind. 
#' Diese Frames enthalten Nachrichten wie "Diese Bilder dürfen aus rechtlichen
#' Gründen nicht gezeigt werden."
#'
#' Ziel ist es datengratragene Krtik am ARD und ZDF zu üben, digitale wie 
#' analoge Rundfunksbeitrag-Zahler gleich zu behandeln.
#' Dafür sollen:
#' 1) Im Falle von Zensur Statistiken per Twitterbot verbreitet werden.
#' 2) Ein Datenarchiv für Medien- & Justizwissenschaftler erstellt werden.
#'
#' Contribution welcome. Helfe mit :-)
#'
#' Usage:
#' Rscript --vanilla bin/MAIN.R hjo 1  # von vor einem Tag
#' Rscript --vanilla bin/MAIN.R h19 `date +%Y%m%d`
#'
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                Preamble                                      #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#### Entwicklungsmodus ####
#' Im Entwicklungsmodus werden die extrahierten Bilder aus dem Sendungsstream
#' nicht gelöscht. Zusätzlich wird das errechnete Ergebnis nicht getwittert. 
#' Der Entwicklungsmodus wird aktiviert indem die Variable `dev` auf TRUE 
#' gesetzt wird. 
opt_dev <- FALSE  # Devmode? Save Images, etc..
opt_git <- TRUE  # Github Interaction
opt_social <- TRUE  # Social Media Interaction

if (opt_dev){
  dir.create("archiv")
}
#### Parameter ####
## Default
res <- 1  # Framerate in Sekunden
wd <- getwd()  # Helps sourcing code in bin/ 
Logfile <- file.path(wd, "Logfile.csv")  # Logfile

# Entfernen von bestehendem nohup Output
file.remove("nohup.out")
(start <- Sys.time())  # Start Time

#### Packages ####
library(jpeg)
library(ggplot2)
library(tibble)
library(lubridate)
library(stringr)
library(magick)
library(rvest)

#### Funktionen ####
## msg Header [1]
header <- function(sendung, date, sep = " vom "){
  if(grepl("h19", sendung))
    s.name <- "ZDF Heute 19Uhr"
  if(grepl("hjo", sendung))
    s.name <- "ZDF HeuteJournal"
  if(grepl("t20", sendung))
    s.name <- "ARD Tagesschau"
  if(grepl("tth", sendung))
    s.name <- "ARD Tagesthemen"
  
  date <- format(date, format = "%d.%m.%Y")
  
  paste(s.name, date, sep = sep)
}

#' Skriptpfad erhalten oder generieren. 
getScriptPath <- function(){
  # https://stackoverflow.com/a/24020199
  cmd.args <- commandArgs()
  m <- regexpr("(?<=^--file=).+", cmd.args, perl=TRUE)
  script.dir <- dirname(regmatches(cmd.args, m))
  if(length(script.dir) == 0) {
    return("bin")  #stop("can't determine script dir: please call the script with Rscript")
  }
  if(length(script.dir) > 1) {
    stop("can't determine script dir: more than one '--file' argument detected")
  }
  return(script.dir)
}
#' Angepasste version von `source`
source2 <- function(file, ...) {
  (file <- file.path(getScriptPath(), file))
  source(file, ...)
}


#### Argumente ####
# Übernahme der Argumente aus dem Rscript-Prozess (siehe [Install.md](../Install.md))
# www.r-bloggers.com/passing-arguments-to-an-r-script-from-command-lines/
# args <- list(sen = "hjo", date = Sys.Date())
# args <- list(sen = "h19", date = format(Sys.Date(), "%Y%m%d"))
args <- commandArgs(trailingOnly=TRUE)
if (length(args)==0) {
  ### Keine Argumente. Default ist h19 von heute.
  warning("Keine Argumente. Verwende default", call.=FALSE)
  # sendung <- "t20"
  sendung <- "h19"
  date <- Sys.Date() - (dateshift <- 0) # Heute
  
} else if (length(args)==1) {
  ### Sendung angegeben. Datum fehlt
  sendung <- args[1]
  date <- Sys.Date() - (dateshift <- 0) # Heute
  
  # Wenn es heute noch vor 19 (20, 23) Uhr ist, wird der gestrige Tag angenommen, da 
  # heutiges Video noch nicht online.
  zeitDerAustrahlung <- switch(sendung, 
                           h19 = 19, 
                           t20 = 20, 
                           hjo = 23, 
                           tth = 22)
  if (lubridate::hour(Sys.time()) < zeitDerAustrahlung){
    date <- date - 1
  }

} else if (length(args)>=2){
  ### Sendung und Datum angegeben
  sendung <- args[1]
  dateshift <- as.numeric(unlist(args[2]))
  date <- Sys.Date() - dateshift
  if(is.na(date)){
    stop("Argument 2 ist keine Zahl und kann nicht vom Datum abgezogen werden.")
  }
# } else if (length(args)==3){
#   ### Debug-Flagge für in der Konsole = 100
#   if (args[3] == 100){
#   opt_dev <- FALSE
#   opt_git <- FALSE
#   opt_social <- FALSE
#   }
}

## Checke ob Sendung zulässig
if(!sendung %in% c("h19", "sendung_h19", "hjo", "sendung_hjo", "t20", "tth")){
  stop("Sendung nicht bekannt")
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                               Processing                                     #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#### Pull aktuelles Repo vom github ####
if(opt_git){ 
  source2("git_pull.R")
}

#### Download ####
source2("download.R", chdir = TRUE)

#### Frames Prozessieren ####
source2("mth_imageAlgebra.R")

# Lösche Bilder wenn nicht im Entwicklungsmodus
if(!opt_dev){ 
  unlink(Temp, recursive = TRUE)
} 

#### Evaluation ####
# Ist die überprüfte Nachrichtensendung vollständig online verfügbar?
if(!TRUE %in% censored){  
  # Gesamte Sendung online verfügbar
  (msg <- paste(c(header(sendung, date)), "vollständig in der Mediathek abrufbar."))
  mediaPath <- NULL

}else{  # Unvollständig. Teile der Nachrichtensendung fehlen
  lubridate2string <- function(x){
    gsub("M ", " Minuten ",
         gsub("S$", " Sekunden", as.period(x)))
  }
  (msg <- paste(header(sendung, date),
                "zeigt", lubridate2string(absolutZensiert), "lang Standbilder.",
                "Das entspricht ", prozentZensiert, "der Sendung."))
  
  # Erstelle Abbildung
  source2("plot.R")
} 



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                            Publish Results                                   #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
if(opt_git){
  #### push Logfile auf Github ####
  source2("git_push.R")
}

if(opt_social){
  #### Add Hashtags ###
  msg <- gsub("ARD", "#ARD", msg)
  msg <- gsub("ZDF", "#ZDF", msg)
  
  #### Twitter ####
  if (require(twitteR) && 
      file.exists("extra/twitter_credentials.R")) {
    source2("tweet.R")
  }
  
  #### Mastodon ####
  if (require(mastodon) && 
      file.exists("extra/mastodon_credentials.R")) {
    source2("toot.R")
  }
  
  #### Telegram Bot Message ####
  if (require(telegram.bot) && 
      file.exists("extra/standbildNews_bot.key") && 
      file.exists("extra/standbildNews_group.id")) {
    source2("telegram_bot.R")
  }
}



#### End Time ####
Sys.time() - start
