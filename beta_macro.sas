%MACRO _BETA (outset,index,crspfile,S=,START=,END=,WINDOW=,MINWIN=);
 
/* Check Series: Daily or Monthly and define datasets - Default is Monthly  */
%if &s=D %then %let s=d; 
%else %if &s ne d %then %let s=m;

%if (%sysfunc(libref(crsp))) %then %do;
	%let cs=/wrds/crsp/sasdata/;
	libname crsp ("&cs/m_stock","&cs/q_stock","&cs/a_stock");
%end;

data mkt;	
	set &index;
		where "&START."D<=date<="&END."D;
	mkt = mkt / 100;
run;

data perms;
	set &crspfile (rename = (check_date = date));
		where "&START."D<=date<="&END."D;
run;

%let sf = perms;
%let si = mkt ;
 
options nonotes;
%put #### START. Computing Betas from &sf Using &WINDOW Estimation Window ;
data _crsp1 /view=_crsp1;
	set &sf. ;
		where "&START."D<=date<="&END."D;
&monthly	date = mdy(month(date),1,year(date));
&daily		date = date;		
		keep permno date ret;
run;

proc sql;
	create table _crsp2
		as select a.*, b.&index, b.&index*(abs(a.ret)>=0) as X, a.ret*b.&index as XY,
  		(abs(a.ret*b.&index)>=0) as count
		from _crsp1 as a left join &si. as b
		on a.date=b.date
order by a.permno, a.date;
quit;
 
proc printto log = junk; run;
proc expand data=_crsp2 out=_crsp3 method=none;
by permno;
id date;
convert X=X2      / transformout= (MOVUSS &WINDOW.);
convert X=X       / transformout= (MOVSUM &WINDOW.);
convert XY=XY     / transformout= (MOVSUM &WINDOW.);
convert ret=Y     / transformout= (MOVSUM &WINDOW.);
convert count=n   / transformout= (MOVSUM &WINDOW.);
quit;
run;
proc printto; run;

proc sort data = _crsp3 out = _crsp4;
	by date permno;
run;
 
data &outset;
set _crsp4;
if n>=&MINWIN. then beta=(XY-X*Y/n) / (X2-(X**2)/n);
label beta = "Stock Beta";
label n = "Number of Observations used to compute Beta";
drop X X2 XY Y COUNT;
format beta comma8.2 ret &index percentn8.2;
run;

/* House Cleaning 
proc sql;
drop view _crsp1;
drop table _crsp2, _crsp3;
quit;
 
options notes;
%put #### DONE . Dataset &outset. Created! ;    %put ;
*/ 
%MEND _BETA;	
