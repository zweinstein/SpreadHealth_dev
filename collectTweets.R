#### Load required packages ####

# Allow R to Run Paralell
require(doMC)
registerDoMC(cores = 4)

# For data analysis and plotting
require(pryr) # for evaluating object_size()
require(data.table)
require(reshape2)
require(RColorBrewer) # Good color for word clouds
require(ggplot2)

# Twitter API Authentication
require("twitteR")
require("ROAuth")

# For natural language processing (NPL)
require(quanteda)

#### Set up Working Directories ####
workDir = "file_path/SpreadHealth_dev" # change this to filepath
dir.create("data")
dataDir = file.path(workDir, "data")
dir.create("intermediate")
interDir = file.path(workDir, "intermediate")
dir.create("out")
outDir = file.path(workDir, "out")

#### Work with Twitter Search API ####

# Set key, secret, token, token_secret correctly, and authenticate
key <- "myKey"
secret <- "mySecret"
token <- "myToken"
token_secret <- "myTokenSecret"

setup_twitter_oauth(key, secret, token, token_secret)

# Set up Keywords for Twitter Searc
# For example, the codes below define 60 keywords related to alternative health approaches
keywords1 <- c("integrative", "alternative", "complementary", "holistic", "herbal", "oriental",
               "chiropractic", "osteopathic", "electromagnetic", "traditional+chinese")
keywords2 <- c("+health", "+medicine", "+therapy", "+treatment")
keywords <- c(as.vector(outer(keywords1, keywords2, paste0)), "acupuncture", "cupping", "ayurveda", 
              "homeopathy", "naturopathy", "massage", "tai+chi", "yoga", "dietary+supplement", 
              "nutrition", "reiki", "qigong", "meditation", "biofeedback", "hypnosis", 
              "visualization+guided+imagery", "energy+healing", "folk+remedies", "folk+medicine", 
              "lifestyle+diets")

keynames <- paste0("t.", gsub("\\+","_",keywords)) # file names

# Search Twitter, Scrape Tweets, and Save (Serialize) Tweets to Disk
# Scraping for 7-8 days of tweets takes quite a few hours.
# Save the tweets as each search completes in case the session crashes.
for (i in 1:length(keynames)) {
  name <- keynames[i]
  tweets  <- searchTwitter(keywords[i], n=80000, lang="en", since='2016-09-18')
  saveRDS(tweets, file=file.path(dataDir, paste0(name,'.rda' )))
}

#### Text Cleaning and Formatting ####

# Load (unserialize) previously saved Twitter data as R objects 
# Convert unstructured data to dataframes, and perform NPL on the 
# dataframes for further analysis
for (name in keynames) {
  df.name <- sub("t", "df", name)
  df.file <- twListToDF(readRDS(file=file.path(dataDir, paste0(name,'.rda' ))))
  assign(df.name, df.file)
  print(file.path(interDir, paste0(df.name,'.csv' )) )
  write.csv(df.file, file = file.path(interDir, paste0(df.name,'.csv' )), row.names = F )
}

rm(df.file, df.name)  

dfnames <- sub("t","df", keynames) # file names

# Combine tweets together and save as one big dataframe by the data collection date
DF <- data.table(rbindlist(lapply(dfnames, get)))

# Remove duplicate tweets
setorder(DF, id)
DF <- DF[!duplicated(DF$id)] 

# Save the data to hard disk
write.csv(DF, file=file.path(interDir, 'tweetsDF20160925.csv'), row.names = F)
rm(list=dfnames) # clean workspace of unnecessary files
# Usually this procedure reduces the object size by 90 % from the original data.
object_size(tweetsDF0709) 

# Create data frame containing only useful data
DT <- data.table(tweet = DF$text, id = DF$id, screenName = DF$screenName,
                 isRT = DF$isRetweet, rtCount = as.numeric(DF$retweetCount))
DToriginal <- DT[!DT$isRT]
setorder(DToriginal, -rtCount)

# Remove  duplicate tweets based on the tweet content
# Only keep duplicate tweets that were retweeted the most 
DTunique <- DToriginal[!duplicated(DToriginal$tweet)] 

DT <- subset(DTunique, select = -isRT) # total 226218 unique tweets
write.csv(DT, file=file.path(interDir, 'tweetsOrigUniq20160925.csv'), row.names = F)

# Pool together new tweets with the tweets collected last week, which have been
# pre-processed with the same codes.
DT1 <- read.csv("file_path/tweetsOrigUniq20160918.csv")
DT <- rbind(DT, DT1)

setorder(DT, -rtCount)
DTunique <- DT[!duplicated(DT$tweet)] 

write.csv(DTunique, file=file.path(interDir, 'tweetsOrigUniq20160918to25.csv'), row.names = F)

#### Get User Info in order to  normalize retweet count by number of followers ####

# A tweet was considered retweeted if it got > 2 retweets.
DT_rt <- DT[DT$rtCount > 2 ] 
# Only need to get User info for the retweeted tweets
users <- droplevels(unique(DT_rt$screenName)) 

# For some reason, the lookupUsers() function kept giving access errors
# I used a for loop to bypass this problem.
userInfo <- getUser(users[1])
userFrame <- twListToDF(userInfo)

n=20
for (i in seq(2, length(users), n) ) {
  temp <- lookupUsers(users[i:(i+n-1)], includeNA = F)  # Batch lookup of user info
  userFrame <- rbind(userFrame, twListToDF(temp))  # Convert to a nice dF
  print(i+n)
}
# Some users information cannot be found (probably related to user consent).

saveRDS(userFrame, 'intermediate/UserInfo0918to25.rda')
userFrame <- readRDS('intermediate/UserInfo0918to25.rda')

DTuser <- subset(userFrame, select = c('screenName', 'followersCount'))
DTalter <- data.table(merge(DT, DTuser, by = 'screenName', all = TRUE))
DTalter <- DTalter[ !is.na(tweet) &  !is.na(rtCount)]
setorder(DTalter, -rtCount)
saveRDS(DTalter, 'intermediate/tweets_w_followers0918to25.rda')

# Retweet percentage relative to the number of followers:
DTalter$pctRT <- DTalter$rtCount / DTalter$followersCount
# Retweet percentage should be zero if the retweet count is zero:
DTalter$pctRT[DTalter$rtCount == 0] = 0
# The remaining NA's for pctRT come from users whose tweets got retweeted but no user information
# was retrieved. There aren't many of those. Just delete them:
DTalter <- DTalter[!is.na(pctRT)]
setorder(DTalter, -pctRT)
DTalter <- DTalter[c(-1,-2)] # delete the top two tweets since they seem to be spam 

# Remove new line symbols in each tweet:
DTalter$tweet  <- gsub("\n", " ", DTalter$tweet)

# Save the file to continue analysis with Python:
saveRDS(DTalter, 'intermediate/tweets_w_pctRT0918to25.rda')
write.csv(DTalter, 'intermediate/tweets_w_pctRT0918to25_rmNL.csv')
