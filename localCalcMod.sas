/******************************************************************************
 _localCalcs runs the iterations of the full data. The lowest level do loop cycles
 through _reps number of repitions. The next level up takes the average from 
 the lowest level and appends that to the macro data set. This repeats for ports
 of size 1 to _max. Finally, the highest level ticks through time, iterating by
 five years at a time.
 ******************************************************************************/

%macro _localCalcs(_max, _reps, _time, _startdt, _hp, _years);
	
	%do j = 1 %to &_time;
		
		%let tempDate = %sysfunc(intnx(YEAR, &_startdt, (&j-1)*&_years, S));
		
		%if (&monthlyDate = 1) %then %do;
			%let nowDate = %sysfunc(mdy(%sysfunc(month(&tempDate)),1,%sysfunc(year(&tempDate))));
			%let thenDate = %sysfunc(intnx(MONTH, &nowDate, &_hp - 1, S));
		%end;
		%if (&monthlyDate = 0) %then %do;
        	        %if (%sysfunc(weekday(&tempDate)) = 1) %then %do;
                	        %let tempDate = %sysfunc(intnx(DAY, &tempDate,1,S));
               		%end;
                	%if (%sysfunc(weekday(&tempDate)) = 7) %then %do;
                        	%let tempDate = %sysfunc(intnx(DAY, &tempDate,2,S));
                	%end;
			%let nowDate = &tempDate;
			%let thenDate = %sysfunc(intnx(DAY, &nowDate, &_hp, S));
		%end;
		
		%do size = 1 %to &_max;
												
			%_setPortfolio(this.rawData, portfolio, &size, &nowDate, &_reps);
			%_fillPortArray(portfolio,this.rawData,fillArrays, &size, &_reps, 
					&nowDate, &thenDate, &_hp);
			%_Rets(fillArrays, monthlyRets);
			%_calcVariance(monthlyRets, calcVar, &_hp);			
			%_addMacro(calcVar, macroSTD, &size, &_reps, &nowDate);
			
&debugmode		options notes;
&debugmode		%put size = &size;
&debugmode		%put time = &j;
&debugmode		%put;
&debugmode		options nonotes;
	
		%end;
	%end;

%mend _localCalcs;
			 

 
