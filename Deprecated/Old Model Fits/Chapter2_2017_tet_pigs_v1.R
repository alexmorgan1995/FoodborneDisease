library("deSolve"); library("ggplot2"); library("plotly"); library("reshape2")
library("bayestestR"); library("tmvtnorm"); library("ggpubr")

rm(list=ls())
setwd("C:/Users/amorg/Documents/PhD/Chapter_2/Chapter2_Fit_Data/FinalData")

#Function to remove negative prevalence values and round large DP numbers
rounding <- function(x) {
  if(as.numeric(x) < 1e-10) {x <- 0
  } else{signif(as.numeric(x), digits = 6)}
}

#Model
amr <- function(t, y, parms) {
  with(as.list(c(y, parms)), {
    dSa = ua + ra*(Isa + Ira) + theta*tau*Isa - (betaAA*Isa*Sa) - (betaAH*Ish*Sa) - (1-alpha)*(betaAH*Irh*Sa) - (1-alpha)*(betaAA*Ira*Sa) - ua*Sa -
      zeta*Sa*(1-alpha) - zeta*Sa 
    dIsa = betaAA*Isa*Sa + betaAH*Ish*Sa + phi*Ira - theta*tau*Isa - tau*Isa - ra*Isa - ua*Isa + zeta*Sa
    dIra = (1-alpha)*betaAH*Irh*Sa + (1-alpha)*betaAA*Ira*Sa + tau*Isa - phi*Ira - ra*Ira - ua*Ira + zeta*Sa*(1-alpha)
    
    dSh = uh + rh*(Ish+Irh) - (betaHH*Ish*Sh) - (1-alpha)*(betaHH*Irh*Sh) - (betaHA*Isa*Sh) - (1-alpha)*(betaHA*Ira*Sh) - uh*Sh 
    dIsh = betaHH*Ish*Sh + betaHA*Isa*Sh - rh*Ish - uh*Ish 
    dIrh = (1-alpha)*(betaHH*Irh*Sh) + (1-alpha)*(betaHA*Ira*Sh) - rh*Irh - uh*Irh 
    return(list(c(dSa,dIsa,dIra,dSh,dIsh,dIrh)))
  })
}

#### Data Import ####
datatetra <- read.csv("resistanceprofAnim_v1.csv")
datatetrahum <- read.csv("resistanceprofHum_v1.csv")
datatetra$mgpcuuseage <- datatetra$mgpcuuseage / 1000; datatetrahum$mgpcuuseage <- datatetrahum$mgpcuuseage / 1000
datatetra$pig_tetra_sales <- datatetra$pig_tetra_sales / 1000; datatetrahum$pig_tetra_sales <- datatetrahum$pig_tetra_sales / 1000
datatetrahum$ResPropHum <- datatetrahum$ResPropHum/ 100 
datatetra <- datatetra[!datatetra$N < 10,]

mean(datatetra$ResPropHum ,na.rm = TRUE)
mean(datatetra$pig_tetra_sales ,na.rm = TRUE)

ggplot()  + geom_point(data = datatetra, aes(x = pig_tetra_sales, y= ResPropAnim)) +
  geom_text(data = datatetra, aes(x = pig_tetra_sales, y= ResPropAnim, label = Country), vjust = -0.5, hjust = - 0.05) +
  scale_x_continuous(expand = c(0, 0), limits = c(0,0.035)) + scale_y_continuous(expand = c(0, 0), limits = c(0,1)) +
  labs(x ="Livestock Antibiotic Usage (g/PCU)", y = "Antibiotic-Resistant Livestock Carriage")

ggplot()  + geom_point(data = datatetrahum, aes(x = pig_tetra_sales, y= ResPropHum)) +
  geom_text(data = datatetrahum, aes(x = pig_tetra_sales, y= ResPropHum, label = Country), vjust = -0.5, hjust = - 0.05) +
  scale_x_continuous(expand = c(0, 0), limits = c(0,0.035)) + scale_y_continuous(expand = c(0, 0), limits = c(0,1)) +
  labs(x ="Livestock Antibiotic Usage (g/PCU)", y = "Antibiotic-Resistant Human Carriage")

#### Approximate Bayesian Computation - Rejection Algorithm ####

summarystatprev <- function(prev) {
  return(prev$ResPropAnim)
}

sum_square_diff_dist <- function(sum.stats, data.obs, model.obs) {
  sumsquare <- sapply(sum.stats, function(x) {
    sumsquare <- abs((x(data.obs) - x(model.obs))^2)
  })
  return(sum(sumsquare))
}

computeDistanceABC_ALEX <- function(sum.stats, distanceABC, fitmodel, tau_range, thetaparm, init.state, times, data) {
  tauoutput <- matrix(nrow = 0, ncol = 4)
  tau_range <- append(tau_range, 0.0122887)
  for (i in 1:length(tau_range)) {
    temp <- matrix(NA, nrow = 1, ncol = 4)
    parms2 = c(ra = thetaparm[["ra"]], rh =  thetaparm[["rh"]], ua = thetaparm[["ua"]], uh = thetaparm[["uh"]], 
               betaAA = thetaparm[["betaAA"]], betaAH = thetaparm[["betaAH"]], betaHH = thetaparm[["betaHH"]], 
               betaHA = thetaparm[["betaHA"]], phi = thetaparm[["phi"]], tau = tau_range[i], theta = thetaparm[["theta"]], 
               alpha = thetaparm[["alpha"]], zeta = thetaparm[["zeta"]])
    out <- ode(y = init.state, func = fitmodel, times = times, parms = parms2)
    temp[1,1] <- tau_range[i]
    temp[1,2] <- (rounding(out[nrow(out),6]) + rounding(out[nrow(out),7]))*100000
    temp[1,3] <- (rounding(out[nrow(out),4]) / (rounding(out[nrow(out),3]) + rounding(out[nrow(out),4])))
    temp[1,4] <- (rounding(out[nrow(out),7]) / (rounding(out[nrow(out),6]) + rounding(out[nrow(out),7])))
    tauoutput <- rbind(tauoutput, temp)
  }
  tauoutput <- data.frame(tauoutput)
  colnames(tauoutput) <- c("tau", "ICombH", "ResPropAnim", "ResPropHum")  
  return(c(distanceABC(list(sum.stats), data, tauoutput[!tauoutput$tau == 0.0122887,]),
           abs(tauoutput$ICombH[tauoutput$tau == 0.0122887] - 3.26),
           abs(tauoutput$ResPropHum[tauoutput$tau == 0.0122887] - 0.35)))
}

#Run the fit - This is where I will build the ABC-SMC Approach

start_time <- Sys.time()

#Where G is the number of generations
prior.non.zero<-function(par){
  prod(sapply(1:5, function(a) as.numeric((par[a]-lm.low[a]) > 0) * as.numeric((lm.upp[a]-par[a]) > 0)))
}

ABC_algorithm <- function(N, G, sum.stats, distanceABC, fitmodel, tau_range, init.state, times, data) {
  for(g in 1:G) {
    i <- 1
    while(i <= N) {
      if(g==1) {
        d_betaAA <- runif(1, min = 0, max = 0.2)
        d_phi <- runif(1, min = 0, max = 0.04)
        d_theta <- runif(1, min = 0, max = 2)
        d_alpha <- rbeta(1, 1.5, 8.5)
        d_zeta <- runif(1, 0, 0.15)
      } else{ 
        p <- sample(seq(1,N),1,prob= w.old) # check w.old here
        par <- rtmvnorm(1,mean=res.old[p,], sigma=sigma, lower=lm.low, upper=lm.upp)
        d_betaAA<-par[1]
        d_phi<-par[2]
        d_theta<-par[3]
        d_alpha<-par[4]
        d_zeta <- par[5]
      }
      if(prior.non.zero(c(d_betaAA, d_phi, d_theta, d_alpha, d_zeta))) {
        m <- 0
        thetaparm <- c(ra = 60^-1, rh =  (5.5^-1), ua = 240^-1, uh = 28835^-1, betaAA = d_betaAA, betaAH = 0.00001, betaHH = 0.00001, 
                       betaHA = 0.00001, phi = d_phi, theta = d_theta, alpha = d_alpha, zeta = d_zeta)
        
        dist <- computeDistanceABC_ALEX(sum.stats, distanceABC, fitmodel, tau_range, thetaparm, init.state, times, data)
        if((dist[1] <= epsilon_dist[g]) && (dist[2] <= epsilon_food[g]) && (dist[3] <= epsilon_AMR[g]) && (!is.na(dist))) {
          # Store results
          res.new[i,]<-c(d_betaAA, d_phi, d_theta, d_alpha, d_zeta)  
          # Calculate weights
          w1<-prod(c(sapply(c(1:3,5), function(b) dunif(res.new[i,b], min=lm.low[b], max=lm.upp[b])),
                     dbeta(res.new[i,4], 1.5, 8.5))) 
          if(g==1){
            
            w2<-1
            
          } else {
            w2<-sum(sapply(1:N, function(a) w.old[a]* dtmvnorm(res.new[i,], mean=res.old[a,], sigma=sigma, lower=lm.low, upper=lm.upp)))
          }
          w.new[i] <- w1/w2
          # Update counter
          print(paste0('Generation: ', g, ", particle: ", i,", weights: ", w.new[i]))
          print(dist)
          i <- i+1
        }
      }
    }#
    sigma <- cov(res.new) 
    res.old <- res.new
    print(res.old)
    w.old <- w.new/sum(w.new)
    colnames(res.new) <- c("betaAA", "phi", "theta", "alpha", "zeta")
    write.csv(res.new, file = paste("results_ABC_SMC_gen_tet_",g,".csv",sep=""), row.names=FALSE)
    ####
  }
}
N <- 1000 #(ACCEPTED PARTICLES PER GENERATION)

lm.low <- c(0, 0, 0, 0, 0)
lm.upp <- c(0.2, 0.04, 2, 1, 0.15)

# Empty matrices to store results (5 model parameters)
res.old<-matrix(ncol=5,nrow=N)
res.new<-matrix(ncol=5,nrow=N)

# Empty vectors to store weights
w.old<-matrix(ncol=1,nrow=N)
w.new<-matrix(ncol=1,nrow=N)

epsilon_dist <- c(2, 1.5, 1, 0.75, 0.55)
epsilon_food <- c(3.26*0.2, 3.26*0.15, 3.26*0.1, 3.26*0.05, 3.26*0.01)
epsilon_AMR <- c(0.35*0.2, 0.35*0.15, 0.35*0.1, 0.35*0.05,  0.35*0.01)

ABC_algorithm(N = 1000, 
              G = 5,
              sum.stats = summarystatprev, 
              distanceABC = sum_square_diff_dist, 
              fitmodel = amr, 
              tau_range = datatetra$pig_tetra_sales, 
              init.state = c(Sa=0.98, Isa=0.01, Ira=0.01, Sh=1, Ish=0, Irh=0), 
              times = seq(0, 2000, by = 100), 
              data = datatetra)

end_time <- Sys.time(); end_time - start_time

#### Test Data ####
data1 <- cbind(read.csv("results_ABC_SMC_gen_tet_1.csv", header = TRUE), "group" = "data1")
data2 <- cbind(read.csv("results_ABC_SMC_gen_tet_2.csv", header = TRUE), "group" = "data2")
data3 <- cbind(read.csv("results_ABC_SMC_gen_tet_3.csv", header = TRUE), "group" = "data3")
data4 <- cbind(read.csv("results_ABC_SMC_gen_tet_4.csv", header = TRUE), "group" = "data4") 
data5 <- cbind(read.csv("results_ABC_SMC_gen_tet_5.csv", header = TRUE), "group" = "data5") 

map_phi <- mean(data5[,"phi"]) 
map_theta <- mean(data5[,"theta"]) 
map_betaAA <- mean(data5[,"betaAA"]) 
map_alpha <- mean(data5[,"alpha"]) 
map_zeta <- mean(data5[,"zeta"]) 

#Plotting the Distributions

testphi <- melt(rbind(data1, data2, data3, data4, data5), id.vars = "group",measure.vars = "phi")
testtheta <- melt(rbind(data1, data2, data3, data4,data5), id.vars = "group",measure.vars = "theta")
testbetaAA <- melt(rbind(data1, data2, data3, data4, data5), id.vars = "group",measure.vars = "betaAA")
testalpha <- melt(rbind(data1, data2, data3, data4, data5), id.vars = "group",measure.vars = "alpha")
testzeta <- melt(rbind(data1, data2, data3, data4, data5), id.vars = "group",measure.vars = "zeta")

p1 <- ggplot(testphi, aes(x=value, fill=group)) + geom_density(alpha=.5) + 
  scale_x_continuous(expand = c(0, 0), name = expression(paste("Rate of Antibiotic-Resistant to Antibiotic-Sensitive Reversion (", phi, ")"))) + 
  scale_y_continuous(limits = c(0,350), expand = c(0, 0), name = "") +
  labs(fill = NULL) + scale_fill_discrete(labels = c("Generation 1", "Generation 2", "Generation 3", "Generation 4", "Generation 5"))+
  theme(legend.text=element_text(size=14),  axis.text=element_text(size=14),
        axis.title.y=element_text(size=14),axis.title.x= element_text(size=14), plot.margin = unit(c(0.5,0.5,0.5,0.5), "cm"))

p2 <- ggplot(testtheta, aes(x=value, fill=group)) + geom_density(alpha=.5)+
  scale_x_continuous(expand = c(0, 0), name = expression(paste("Efficacy of Antibiotic-Mediated Animal Recovery (", theta, ")"))) + 
  scale_y_continuous(limits = c(0,1), expand = c(0, 0), name = "") +
  labs(fill = NULL) + scale_fill_discrete(labels = c("Generation 1", "Generation 2", "Generation 3", "Generation 4", "Generation 5")) +
  theme(legend.text=element_text(size=14),  axis.text=element_text(size=14),
        axis.title.y=element_text(size=14),axis.title.x= element_text(size=14), plot.margin = unit(c(0.5,0.5,0.5,0.5), "cm"))

p3<- ggplot(testbetaAA, aes(x=value, fill=group)) + geom_density(alpha=.5)+
  scale_x_continuous(expand = c(0, 0), name = expression(paste("Rate of Animal-to-Animal Transmission (", beta[AA], ")"))) + 
  scale_y_continuous(limits = c(0,40),expand = c(0, 0), name = "") +
  labs(fill = NULL) + scale_fill_discrete(labels = c("Generation 1", "Generation 2", "Generation 3", "Generation 4", "Generation 5")) +
  theme(legend.text=element_text(size=14),  axis.text=element_text(size=14),
        axis.title.y=element_text(size=14),axis.title.x= element_text(size=14), plot.margin = unit(c(0.5,0.5,0.5,0.5), "cm"))

p4 <- ggplot(testalpha, aes(x=value, fill=group)) + geom_density(alpha=.5)+
  scale_x_continuous(expand = c(0, 0), name = expression(paste("Transmission-related Antibiotic Resistant Fitness Cost (", alpha, ")"))) + 
  scale_y_continuous(limits = c(0,12),expand = c(0, 0), name = "") +
  labs(fill = NULL) + scale_fill_discrete(labels = c("Generation 1", "Generation 2", "Generation 3", "Generation 4", "Generation 5")) +
  theme(legend.text=element_text(size=14),  axis.text=element_text(size=14),
        axis.title.y=element_text(size=14),axis.title.x= element_text(size=14), plot.margin = unit(c(0.5,0.5,0.5,0.5), "cm"))

p5 <- ggplot(testzeta, aes(x=value, fill=group)) + geom_density(alpha=.5)+
  scale_x_continuous(expand = c(0, 0), name = expression(paste("Background Infection Rate (", zeta, ")"))) + 
  scale_y_continuous(expand = c(0, 0), name = "") +
  labs(fill = NULL) + scale_fill_discrete(labels = c("Generation 1", "Generation 2", "Generation 3", "Generation 4", "Generation 5")) +
  theme(legend.text=element_text(size=14),  axis.text=element_text(size=14),
        axis.title.y=element_text(size=14),axis.title.x= element_text(size=14), plot.margin = unit(c(0.5,0.5,0.5,0.5), "cm"))


#### Plotting ####

plot <- ggarrange(p1, p2, p3, p4,p5, nrow = 3, ncol =2, 
                  labels = c("A","B","C","D","E"), font.label = c(size = 20), common.legend = TRUE, legend = "bottom")

ggsave(plot, filename = "ABCSMC_salm_pigs.png", dpi = 300, type = "cairo", width = 13, height = 15, units = "in")

#### Testing the Model #### 

parmtau <- c(seq(0, 0.035,by=0.001), 0.0122887)

init <- c(Sa=0.98, Isa=0.01, Ira=0.01, Sh=1, Ish=0, Irh=0)
output1 <- data.frame()
times <- seq(0, 200000, by = 100)

for (i in 1:length(parmtau)) {
  temp <- data.frame(matrix(NA, nrow = 1, ncol=7))
  parms2 = c(ra = 60^-1, rh =  (5.5^-1), ua = 240^-1, uh = 28835^-1, betaAA = map_betaAA, betaAH = 0.00001, betaHH = 0.00001, 
             betaHA = (0.00001), phi = map_phi, theta = map_theta, alpha = map_alpha, tau = parmtau[i], zeta = map_zeta)
  out <- ode(y = init, func = amr, times = times, parms = parms2)
  temp[1,1] <- parmtau[i]
  temp[1,2] <- rounding(out[nrow(out),5]) 
  temp[1,3] <- rounding(out[nrow(out),6]) 
  temp[1,4] <- rounding(out[nrow(out),7])
  temp[1,5] <- temp[1,3] + temp[1,4]
  temp[1,6] <- signif(as.numeric(temp[1,4]/temp[1,5]), digits = 3)
  temp[1,7] <- rounding(out[nrow(out),4]) / (rounding(out[nrow(out),3]) + rounding(out[nrow(out),4]))
  print(temp[1,3])
  output1 <- rbind.data.frame(output1, temp)
}

colnames(output1)[1:7] <- c("tau", "SuscHumans","InfHumans","ResInfHumans","ICombH","IResRat","IResRatA")

output2 <- output1
output2[,2:5] <- output2[,2:5]*100000 #Scaling the prevalence (per 100,000)

plot_ly(output2, x= ~tau, y = ~InfHumans, type = "bar", name = "Antibiotic-Sensitive Infection (Human)") %>%
  add_trace(y= ~ResInfHumans, name = "Antibiotic-Resistant Infection (Human)", textfont = list(size = 30)) %>% 
  layout(yaxis = list(title = "Proportion of Infected Humans (ICombH) per 100,000", range = c(0,6), showline = TRUE),
         xaxis = list(title = "Livestock Antibiotic Usage (g/PCU)"),
         legend = list(orientation = "v", x = 0.6, y=1), showlegend = T,
         barmode = "stack", annotations = list(x = ~tau, y = ~ICombH, text = ~IResRat, yanchor = "bottom", showarrow = FALSE, textangle = 310,
                                               xshift =3))

#### Showing the Fit with Data #### 

parmtau <- seq(0,0.035, by = 0.001)

init <- c(Sa=0.98, Isa=0.01, Ira=0.01, Sh=1, Ish=0, Irh=0)
output1 <- data.frame()
times <- seq(0, 200000, by = 100)

for (i in 1:length(parmtau)) {
  temp <- data.frame(matrix(NA, nrow = 1, ncol=7))
  parms2 = c(ra = 60^-1, rh =  (5.5^-1), ua = 240^-1, uh = 28835^-1, betaAA = map_betaAA, betaAH = 0.00001, betaHH = 0.00001, 
             betaHA = (0.00001), phi = map_phi, theta = map_theta, alpha = map_alpha, tau = parmtau[i], zeta = map_zeta)
  out <- ode(y = init, func = amr, times = times, parms = parms2)
  temp[1,1] <- parmtau[i]
  temp[1,2] <- rounding(out[nrow(out),5]) 
  temp[1,3] <- rounding(out[nrow(out),6]) 
  temp[1,4] <- rounding(out[nrow(out),7])
  temp[1,5] <- temp[1,3] + temp[1,4]
  temp[1,6] <- signif(as.numeric(temp[1,4]/temp[1,5]), digits = 3)
  temp[1,7] <- rounding(out[nrow(out),4]) / (rounding(out[nrow(out),3]) + rounding(out[nrow(out),4]))
  print(temp[1,3])
  output1 <- rbind.data.frame(output1, temp)
}

colnames(output1)[1:7] <- c("tau", "SuscHumans","InfHumans","ResInfHumans","ICombH","IResRat","IResRatA")

output2 <- output1
output2[,2:5] <- output2[,2:5]*100000 #Scaling the prevalence (per 100,000)

ggplot()  + geom_point(data = datatetra, aes(x = pig_tetra_sales, y= ResPropAnim)) +
  geom_text(data = datatetra, aes(x = pig_tetra_sales, y= ResPropAnim, label = Country), vjust = -0.5, hjust = - 0.05) +
  scale_x_continuous(expand = c(0, 0), limits = c(0,0.035)) + scale_y_continuous(expand = c(0, 0), limits = c(0,1)) +
  labs(x ="Livestock Antibiotic Usage (g/PCU)", y = "Antibiotic-Resistant Livestock Carriage") + 
  geom_line(data = output2, aes(x = tau, y= IResRatA), col = "darkred", size = 1.02)
