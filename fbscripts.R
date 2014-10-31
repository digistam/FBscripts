fbscraper <- function(x) {
  if (!require("XML")) {
    install.packages("XML", repos="http://cran.rstudio.com/")
    library(XML)
  }
  if (!require("RCurl")) {
    install.packages("RCurl", repos="http://cran.rstudio.com/")
    library(RCurl)
  }
  if (!require("rjson")) {
    install.packages("rjson", repos="http://cran.rstudio.com/")
    library(rjson)
  }
  files <- list.files(path = x, full.names=T, pattern="*.htm*", recursive=FALSE)
  name <- c() ## global name variable
  id <- c() ## global id variable
  gender <- c() ## global gender variable
  locale <- c() ## global locale variable
  link <- c() ## global link variable
  for (item in files) {
    graphdata <- readLines(item)
    html.raw <- htmlTreeParse(graphdata,error=function(...){}, useInternalNodes = T, encoding = 'UTF-8', trim = T)
    html.parse <- getNodeSet(html.raw,"//*[@class='clearfix _zw']")
    # get the profile info
    profiles <- xpathSApply(html.raw,"//a[@href][@class='_7kf _8o _8s lfloat _ohe']", xmlGetAttr, "href")
    profiles <- gsub("\\?.*","",profiles)
    profiles <- gsub("https://www.facebook.com/","",profiles)
    userList <- capture.output(write.table(matrix(as.character(profiles),nrow=1), sep=",",row.names=FALSE, col.names=FALSE, quote=FALSE))
    userList <- gsub("profile.php","",userList)
    userList <- gsub(",,",",",userList)
    userList <- gsub(",$","",userList)
    # print(userList)
    json_file <- paste('http://graph.facebook.com/?ids=',userList,sep="")
    raw <- getURL(json_file,.opts = list(ssl.verifypeer = FALSE))
    userDetails <- fromJSON(raw)
    for (i in 1:length(userDetails)) {
      name <- c(name,userDetails[[i]]$name);id <- c(id,userDetails[[i]]$id);gender <- c(gender,userDetails[[i]]$gender);locale <- c(locale,userDetails[[i]]$locale);link <- c(link,userDetails[[i]]$link)
    }}
  df <- as.data.frame(cbind(name,id,gender,locale))
  write.csv(df,file="demo.csv",row.names=FALSE)
#   df <- read.csv('demo.csv')
#   df$id <- as.character(df$id)
#   print(df)
  #write.table(paste(id,',#',name,sep=""),file='test.txt',quote = FALSE, col.names = F, row.names = F)
  #write.table(df, file = "demo.csv", append = FALSE, quote = TRUE, sep = ";",eol = "\n", na = "NA", dec = ".", row.names = FALSE,col.names = TRUE, qmethod = c("escape", "double"),fileEncoding = "UTF-8")
}
createDbase <- function(x) {
  df <- read.csv('demo.csv')
  df$id <- as.character(df$id)
  userList <- capture.output(write.table(matrix(as.character(df$id),nrow=1), sep=",",row.names=FALSE, col.names=FALSE, quote=FALSE))
  ## create facebookobjects.py
  sink('facebookobjects.py')
  cat("objects = [\n")
  cat(userList)
  cat("]")
  sink()
}
connectSQL <- function(x) {
  if (!require("RSQLite")) {
    install.packages("RSQLite", repos="http://cran.rstudio.com/")
    library(RSQLite)
  }
  set.seed(111)
  drv <<- dbDriver("SQLite")
  con <<- dbConnect(drv, x)
  #dbListTables(con)
  queryTable('stream','likes')
}
queryTable <- function(x,y) {
  library(lubridate)
  if (!require("lubridate")) {
    install.packages("lubridate", repos="http://cran.rstudio.com/") 
    library("lubridate") 
  }
  set.seed(111)
  q <- dbGetQuery(con, paste("SELECT * FROM ", x, " order by date DESC", sep=""))
  DFcontent <<- as.data.frame.matrix(q)
  q <- dbGetQuery(con, paste("SELECT * FROM ", y, "", sep=""))
  DFlikes <<- as.data.frame.matrix(q)  
#   DF$date <- as.POSIXct(DF$date,format = "%Y-%m-%dT%H:%M:%S+0000", tz = "UTC")
#   DF$date <- with_tz(DF$date, "Europe/Paris")
#   DF <<- as.data.frame(q)
}
cleanHTML <- function(x) {
  return(gsub("<.*?>", "", x))
}
video <- function() {
  video <- DFcontent$link[grep('(http://.*meo.com/.*|http://.*tube.com/.*|http://.*tu.be/.*|.*video.*)',DFcontent$link)]
  video <- table(cleanHTML(video))
  video <- as.data.frame(as.table(video))
  video <- video[order(video$Freq,decreasing=T),]
  names(video) <- c('video','Freq')
  video <<- as.data.frame(video[,c(2,1)])
}
weblinks <- function() {
  weblinks <- DFcontent$link
  weblinks <- table(cleanHTML(weblinks))
  weblinks <- as.data.frame(as.table(weblinks))
  weblinks <- weblinks[order(weblinks$Freq,decreasing=T),]
  names(weblinks) <- c('weblink','Freq')
  weblinks <<- as.data.frame(weblinks[,c(2,1)])
}
likeGraph <- function() {
  library(igraph)
  if (!require("igraph")) {
    install.packages("igraph", repos="http://cran.rstudio.com/") 
    library("igraph") 
  }
  set.seed(111)
  DF <<- merge(DFcontent, DFlikes, by = 'post_id',incomparables = NULL, all.x = TRUE)
  names(DF) <- c("post_id","id","object_id","type","object_name","post_url","actor","actor_url","actor_id","actor_pic","date","message","story","link","description","comments","likes","application","like_id","liker","liker_url","liker_id","liker_pic")
  graph <- cbind(DF$liker,DF$actor)
  graph <- na.omit(unique(graph))
  g <<- graph.data.frame(graph, directed = T)
}