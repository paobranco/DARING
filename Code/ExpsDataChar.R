library(e1071)                 # where the svm is
library(performanceEstimation) # exps framework
library(randomForest)          # randomForest
library(earth)                 # MARS reimplementation
library(UBL)                   # smoteR
library(uba)                   # utility-based evaluation framework

# setwd("~/AnalysisDataCharacteristicsImbalancedData/ExpsCode/")

source("Auxs.R")
##############################################################
# THE USED DATA SETS
# ============================================================
S <- c(1,2,3,4,5)
I <- c("045", "035", "025", "01", "005")
O <- c(1,2,3,4)
D <- c(1,2,3)

DSsNames <- c()
for(ns in S){
 for(ni in I){
  for(no in O){
   for(nd in D){
    DSsNames <- c(DSsNames, paste("S", ns,"I", ni,"O", no, "D", nd, sep="")) 
   }
  }
 }
}

# setwd("~/AnalysisDataCharacteristicsImbalancedData/Data/Rep1")

# change the follwoing line to set with repetition of the data you want to use
load("DSsRep1.RData")
#names(DSs) <- DSsNames
#########################################################################
# to generate information about the data sets for a given threshold
#########################################################################
PCSall <- list()

for(d in 1:length(DSsNames))
{
  ds <- DSs[[d]]@data
  y <- ds$Tgt
#  pc <- phi.control(y, method="extremes")
  pc <- phi.control(y, method="extremes", extr.type="low")
  if (all(pc$control.pts[c(2,5,8)]<0.8)){ 
    # the data set does not have extremes (because it is approximatly balanced!)
    # in this case we assume that the low extreme tgt values
    # are the most relevant
    imbNr <- as.numeric(strsplit(strsplit(DSs[[d]]@name, "I")[[1]][2], "O")[[1]][1])
    if(imbNr == 1){
     imbNr <- imbNr/10 
    } else {
     imbNr <- imbNr/100 
    }
    sy <- sort(y)
    pc$control.pts[1] <- sy[nrow(ds)*imbNr]
    pc$control.pts[2] <- 1
  }
  lossF.args <- loss.control(y)
  PCSall[[d]] <- list(pc, lossF.args)
  
}

thr.rel <- 0.8

PCS <- NULL
for(j in 1:length(DSsNames)){PCS[[j]] <- PCSall[[j]]}


# loaded with EstPredTask.R
# for(i in 1:240){
#   cat(paste("PredTask(Tgt~., DSs[[",i,"]]@data, DSsNames[",i,"]),\n", sep=""))
# }

  

# weight for penalizing FP ot FN
p <- 0.5
##########################################################################
# learners and estimation procedure
##########################################################################

WFs <- list()
WFs$svm <- list(learner.pars=list(cost=c(10,150,300), gamma=c(0.01,0.001)))
WFs$randomForest <- list(learner.pars=list(ntree=c(500,750,1000,1500)))
WFs$earth <- list(learner.pars=list(nk=c(10,17),degree=c(1,2),thresh=c(0.01,0.001)))


# exps with 2 times 10 fold CV
# setwd("~/AnalysisDataCharacteristicsImbalancedData/ExpsCode/")

source("EstPredTasks.R")

# return to the results file
# setwd("~/AnalysisDataCharacteristicsImbalancedData/Data/Rep1/Res")

##########################################################################
# exps
##########################################################################

for(d in 1:300){
#for(d in 1:length(DSsNames)){
  for(w in names(WFs)) {
    resObj <- paste(myDSs[[d]]@taskName,w,'Res',sep='')
    assign(resObj,
           try(
             performanceEstimation(
               myDSs[[d]],         
               c(
                 do.call('workflowVariants',
                         c(list('WFnone', learner=w),
                           WFs[[w]],
                           varsRootName=paste('WFnone',w,sep='.')
                           )),
                 do.call('workflowVariants',
                         c(list('WFRandUnder',learner=w,
                                rel=matrix(PCS[[d]][[1]][[3]], nrow=3, ncol=3, byrow=TRUE),
                                thr.rel=thr.rel,
                                C.perc="balance",
                                repl=FALSE),
                           WFs[[w]],
                           varsRootName=paste('WFRandUnder',w,sep='.'),
                           as.is="rel"
                         )),
                 do.call('workflowVariants',
                         c(list('WFRandOver',learner=w,
                                rel=matrix(PCS[[d]][[1]][[3]], nrow=3, ncol=3, byrow=TRUE),
                                thr.rel=thr.rel,
                                C.perc="balance",
                                repl=TRUE),
                           WFs[[w]],
                           varsRootName=paste('WFRandOver',w,sep='.'),
                           as.is="rel"
                         )),
                 do.call('workflowVariants',
                         c(list('WFsmote',learner=w,
                                rel=matrix(PCS[[d]][[1]][[3]], nrow=3, ncol=3, byrow=TRUE),
                                thr.rel=thr.rel,
                                C.perc="balance",
                                k=5, repl=FALSE,
                                dist="HEOM", p=2),
                           WFs[[w]],
                           varsRootName=paste('WFsmote',w,sep='.'),
                           as.is="rel"
                         )),
                 do.call('workflowVariants',
                         c(list('WFGN',learner=w,
                                rel=matrix(PCS[[d]][[1]][[3]], nrow=3, ncol=3, byrow=TRUE),
                                thr.rel=thr.rel,
                                C.perc="balance",
                                pert= 0.1,
                                repl=FALSE),
                           WFs[[w]],
                           varsRootName=paste('WFGN',w,sep='.'),
                           as.is="rel"
                         ))
                 ),
               CVsetts[[d]])
           )
      )
    if (class(get(resObj)) != 'try-error') save(list=resObj,file=paste(myDSs[[d]]@taskName,w,'Rdata',sep='.'))
  }
}

