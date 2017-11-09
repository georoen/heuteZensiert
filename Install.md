# Installation
Um das Programm zu installieren,  müssen folgende Dependencies erfüllt sein:  
  **Linux** `sudo apt install ffmpeg imagemagick libmagick++-dev libtesseract-dev libleptonica-dev tesseract-ocr-eng tesseract-ocr-deu`.  
**R:** `install.packages(c("jpeg", "rvest", "ggplot2", "tibble", "lubridate", "stringr", "magick", "tesseract", "twitteR"), repos = "https://cran.rstudio.com")`

Hier werden mit [`CRONTAB`](https://wiki.ubuntuusers.de/Cron/) täglich die Nachrichten-Sendungen, 50 Minuten nach regulärer TV-Ausstrahlung, via RSS abgerufen.
```
# 50 19 * * * cd ~/heuteZensiert/ && nohup Rscript --vanilla bin/heuteZensiert.R h19 &
# 50 20 * * * cd ~/heuteZensiert/ && nohup Rscript --vanilla bin/heuteZensiert.R t20 &
# 50 23 * * *  cd ~/heuteZensiert/ && nohup Rscript --vanilla bin/heuteZensiert.R hjo &
```
