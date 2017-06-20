/******************************************************************************
 This code calculates the standard deviations of different sizes of portfolios
 moving across time. Below is where the code can be toggled to change the
 parameters on max size of portfolio ( = max), number of repetitions per portfolio
 ( = reps) and time period to go through ( = time; note that this refers to
 increments of five years).
 ******************************************************************************/

/* TURN ON TO RUN MONTHLY */
%let monthly 		= ;
%let daily 		= *;
%let monthlyDate 	= 1;
%let startdt 		= '01JAN1970'd;
%let hp		= 12;
%let hpunit		= 'MONTH';

/* TURN ON TO RUN DAILY */
*%let monthly 		= *;
*%let daily 		= ;
*%let monthlyDate 	= 0;
*%let startdt		= '03JAN2012'd;
*%let hp			= 365;
*%let hpunit		= 'DAY';
*%let numyears		= 1;

/* TURN ON TO RUN DEBUG; TURN OFF WHEN RUNNING CODE */
%let debugmode = *;
*%let debugmode = ;

/* Only need these for the first time it is run */
%let betastart 	= '01JAN1960'D;
%let betaend	= '01MAY2016'D;


%let max 	= 100;
%let reps	= 1000;	
%let time	= 1;

&debugmode options nonotes;

%include "setPortMod.sas";
%include "localCalcMod.sas";
%include "beta_macro.sas";

/* ONLY RUN ONCE */
%_setUp(&betastart, &betaend, &startdt);
endsas;
%_localCalcs(&max, &reps, &time, &startdt, &hp, &numyears);

%let dir = .;
ods csv file = "&dir/portfolio.csv";
 
proc print data = macroSTD;
run;

ods trace on;
ods csv close;

