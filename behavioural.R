library(readxl)
library(dplyr)
library(rstatix)
library(reshape2)
library(tibble)

#-------------------data preparation and preprocessing-------------------------#

#importing data
behavioural_data <- read_excel("Documents/behavioural.xlsx", na = "NA")


#cleaning data
str(behavioural_data)

#to fix:
#1. t1_resp is string
#2. IB variables (CT_notice, DA_Notice, FA_notice) are character variables and need to be cleaned
#3. factor variables need to be factorized
#4. no composite IB noticing (CT + DA) variable

#t1 as numeric
behavioural_data$T1_response <- as.numeric(behavioural_data$T1_response)

#creating factors
factor_variables <- c('gender', 'handedness', 'CT_notice', 'DA_notice', 'FA_notice')
behavioural_data[,factor_variables] <- lapply(behavioural_data[,factor_variables], factor)

#fixing IB variable
levels(behavioural_data$CT_notice)
cleaning_CT_notice <- c("N", "N", "Y")
levels(behavioural_data$CT_notice) <- cleaning_CT_notice #fixed

#composite CT_notice + DA_notice variable
behavioural_data$comp_notice <- case_when(
  behavioural_data$CT_notice == "Y" | behavioural_data$DA_notice == "Y" ~ "Y",
  TRUE ~ "N")
behavioural_data$comp_notice <- as.factor(behavioural_data$comp_notice)

#rechecking
str(behavioural_data)


#--------error scores------#

behavioural_data <- add_column(.data = behavioural_data,
                                 t1_error = abs(behavioural_data$T1_actual - behavioural_data$T1_response),
                                 t2_error = abs(behavioural_data$T2_actual - behavioural_data$T2_response),
                                 t3_error = abs(behavioural_data$T3_actual - behavioural_data$T3_response),
                                 t4_error = abs(behavioural_data$T4_actual - behavioural_data$T4_response),
                                 t5_error = abs(behavioural_data$T5_actual - behavioural_data$T5_response),
                                 t6_error = abs(behavioural_data$T6_actual - behavioural_data$T6_response)
                                 )

#creating composite error score variables (overall, practice, and critical [CT + DA])
behavioural_data$overall_error <- rowMeans(behavioural_data[,23:28], na.rm = TRUE)
behavioural_data$practice_error <- rowMeans(behavioural_data[,23:26], na.rm = TRUE)
behavioural_data$critical_error <- rowMeans(behavioural_data[,27:28], na.rm = TRUE)

#removing participant ID 4 and FA IB participants
behavioural_data_2 <- behavioural_data[!behavioural_data$FA_notice == "N",] #remove FA IB participants
behavioural_data_3 <- behavioural_data_2[-c(1),] #remove participant ID 4

#----------------------------summary stats-------------------------------------#

IB_rates_CT <- prop.table(table(behavioural_data_3$CT_notice)) * 100
IB_rates_CT

IB_rates_DA <- prop.table(table(behavioural_data_3$DA_notice)) * 100
IB_rates_DA

IB_rates_comp <- prop.table(table(behavioural_data_3$comp_notice)) * 100
IB_rates_comp

summary_behavioural <- behavioural_data_3 %>%
  #group_by(comp_notice) %>% #(un)hash this for difference between groups / overall
  summarise(
    t1_error=mean(t1_error, na.rm =TRUE),
    SD_t1 = sd(t1_error, na.rm =TRUE),
    t2_error=mean(t2_error, na.rm =TRUE),
    SD_t2 = sd(t2_error, na.rm =TRUE),
    t3_error=mean(t3_error, na.rm =TRUE),
    SD_t3 = sd(t3_error, na.rm =TRUE),
    t4_error=mean(t4_error, na.rm =TRUE),
    SD_t4 = sd(t4_error, na.rm =TRUE),
    t5_error=mean(t5_error, na.rm =TRUE),
    SD_t5 = sd(t5_error, na.rm =TRUE),
    t6_error=mean(t6_error, na.rm =TRUE),
    SD_t6 = sd(t6_error, na.rm =TRUE),
    overall_error=mean(overall_error, na.rm =TRUE),
    SD_overall = sd(overall_error, na.rm =TRUE),
    practice_error=mean(practice_error, na.rm =TRUE),
    SD_practice = sd(practice_error, na.rm =TRUE),
    critical_error=mean(critical_error, na.rm =TRUE),
    SD_critical = sd(critical_error, na.rm =TRUE)
  )
View(summary_behavioural)



#------------------------------Analyses----------------------------------------#

#median to replace NA's as BF does not allow missing values
behavioural_data_3$t1_error[11] <- median(behavioural_data_3$t1_error, na.rm = T)
behavioural_data_3$t1_error[35] <- median(behavioural_data_3$t1_error, na.rm = T)

#for ANOVA, need the data in long format
behavioural_data_long <- reshape2::melt(behavioural_data_3,
                          id.vars = c("subject", "CT_notice", "DA_notice", "comp_notice", "gender", "handedness", "counter balance"),
                          measure.vars = c("t1_error", "t2_error", "t3_error", "t4_error", "t5_error", "t6_error"),
                          variable.name = "trial", 
                          value.name = "error_rate")

#task performance mixed factorial ANOVA
ct.aov <- anova_test(data = behavioural_data_long,
                     dv = error_rate,
                     wid = subject,
                     within = trial,
                     between = comp_notice,
                     effect.size = "pes")
ct.aov

#pairwise comparisons for ANOVA
er.pwc <- behavioural_data_long %>% 
  pairwise_t_test(error_rate ~ trial,
                  p.adjust.method = "bonferroni",
                  paired = TRUE,
                  pooled.sd = FALSE,
                  detailed = TRUE,
                  conf.level = 0.95)
er.pwc

#two sample t tests for task performance

#---average error score t test
overall_t <- t.test(formula = overall_error ~ comp_notice,
       data = behavioural_data_3,
       var.equal = FALSE,
       alternative = "two.sided",
       conf.level = .95)
cohens_d(formula = overall_error ~ comp_notice,
         data = behavioural_data_3,
         var.equal = FALSE,
         hedges.correction = TRUE)

#---critical trial error score t test
critical_t <- t.test(formula = t5_error ~ CT_notice,
       data = behavioural_data_3,
       var.equal = FALSE,
       alternative = "two.sided",
       conf.level = .95)
cohens_d(formula = t5_error ~ CT_notice,
         data = behavioural_data_3,
         var.equal = FALSE,
         hedges.correction = TRUE)

#---divided attention trial error score t test
divided_t <- t.test(formula = t6_error ~ DA_notice,
       data = behavioural_data_3,
       var.equal = FALSE,
       alternative = "two.sided",
       conf.level = .95)
cohens_d(formula = t6_error ~ DA_notice,
         data = behavioural_data_3,
         var.equal = FALSE,
         hedges.correction = TRUE)

