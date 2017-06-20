/******************************************************************************
 _setUp calculates market values, returns and excess returns (using French mkt
 values) for the applicable data set. This data set will be only share codes of 
 10 and 11, only within the date range, and only if the necessary data exists for
 the security. Note that betas are calculated with a window of 36 months, and a 
 minimum window of 12 months.

 THIS SHOULD BE RUN ONCE AND THEN TURNED OFF.
 ******************************************************************************/

%macro _setUp(_betast, _betaend, _startdt);

	/* Sets up the crsp data set*/

	data getData (keep = check_date permno ret mktval hexcd);
	
&monthly	merge crsp.msf crsp.msenames;
&daily		merge crsp.dsf crsp.msenames;
			by permno;

&monthly	check_date = mdy(month(date),1,year(date));
&daily		check_date = date;
		format check_date date9.;
		mktval = lag(abs(prc)) * lag(shrout);
		if (first.permno) then mktval = .;

		/* Uses the above mentioned criteria to determine what to output */

		if (check_date >= &_betast) then do;
			if (shrcd = 10) or (shrcd = 11) then do;
				if (mktval ne .) and (ret ne .) then output;
			end;
		end;
	run;

	proc sort data = getData out = tempraw;
		by check_date permno;
	run;

	/* Imports and sorts the French mkt file */

&monthly	proc import out = temp5 datafile = "market.xls" dbms = xls;
&daily		proc import out = temp5 datafile = "market_daily.xls" dbms = xls;
		run;

	proc sort data = temp5 out = mkt;
		by date;
	run;

	/* Call macro to figure out betas for each security */

&monthly	%_beta(betas, mkt, tempraw, S=m, START = &_betast, END = &_betaend, WINDOW = 36, MINWIN = 12);
&daily		%_beta(betas, mkt, tempraw, S=d, START = &_betast, END = &_betaend, WINDOW = 36, MINWIN = 12);

	/* Calculates the excess returns and configures the full data set */

	data this.rawData(keep = permno check_date ret excess_ret mktval);

		retain permno check_date ret excess_ret mktval;

		merge betas mkt tempraw (rename = (check_date = date));
			by date;

		rf = rf / 100;

		exp_ret = rf + beta*(mkt);
		excess_ret = ret - exp_ret;
		format excess_ret percentn8.2;
	
		check_date = date;
		format check_date date9.;

		if (check_date >= &_startdt) then output;

	run;	

%mend _setUp;

/******************************************************************************
 _setPort sets up the initial portfolio. It takes the full data set and trims it
 down to only the starting date. Then from this starting date it uses proc 
 survey select to randomly select the appropriate number of permnos. These serve
 as a starting portfolio.
 ******************************************************************************/

%macro _setPortfolio(_fulldata, _otfile, _size, _startdt, _reps);

	data &_otfile(keep = permno);
			
		maxsize = &_size * &_reps;

		array _allPerms(10000)		_temporary_;
		array _portPerms(100000)	_temporary_;	
		
		if(_n_ = 1) then j = 0;
	
		do until (eof);
			set &_fulldata(where = (check_date = &_startdt)) end = eof;
				by check_date permno;
				
			j = j + 1;
			_allPerms(j) = permno;
		end;

		do i = 1 to &_reps;
			do k = 1 to &_size;
				do until (flag1 ne 0);
					a = 0;
					do until (a ne 0);
						a = int(ranuni(0)*j);
					end;
					flag1 = 1;
					do x = 1 to &_size;
						chk = (i-1)*&_size + x;
						if _portPerms(chk) = _allPerms(a) then flag1 = 0;
					end;
				end;
				pos = (i-1)*&_size + k;
				_portPerms(pos) = _allPerms(a);
			end;
		end;

		do n = 1 to maxsize;
			permno = _portPerms(n);
			output;
		end;
	run;

%mend _setPortfolio;

/******************************************************************************
 _fillPortArray serves as the meat of the code. Here the excess return, return
 and market values are pulled from the full data set and followed in the port.
 This code also checks to make sure that the data exists for each security, and
 if it is missing for any reason, it randomly selects a new permno until the 
 data is found to exist. It will then use this permno going forward in the port.
 ******************************************************************************/

%macro _fillPortArray(_portfolio, _fullData, _otfile, _size, _reps, _startdt, _enddt, _hp);

	data tempFill (keep = date permno ret mkt exc portnum);
		
		retain portnum permno date ret exc mkt;
	
		maxsize = &_size * &_reps;
	
		array _initPerms(100000)	_temporary_;
		array _allPerms	(10000)		_temporary_;
		array _rets	(10000:99999)	_temporary_;
		array _excret	(10000:99999)	_temporary_;
		array _mkt	(10000:99999)	_temporary_;
		array _portRets	(100000000)	_temporary_;
		array _portExc	(100000000)	_temporary_;
		array _portDates(100000000)	_temporary_;
		array _portPerms(100000000)	_temporary_;
		array _portMkt	(100000000)	_temporary_;	
		array _portNum	(100000000)	_temporary_;	

		retain idx ct_total flag1;

		/* Fills the portfolio array with inital perms */

		if (_n_ = 1) then do;
			
			idx = 0;
			ct_init = 0;

			do until (eof1);
				ct_init + 1;
				set &_portfolio end = eof1;
				_initPerms(ct_init) = permno;
			end;
		end;
		
		retain currentDate;
		ct_total = 0;

		/* Fills the arrays with the available information */

		do until (last.check_date);
			set &_fullData (where = (check_date between &_startdt and &_enddt));
				by check_date;
			
			ct_total + 1;

			currentDate 	= check_date;
			format currentDate date9.;

			_rets(permno) 	= ret;
			_excret(permno)	= excess_ret;
			_mkt(permno)	= mktval;
			_allPerms(ct_total) = permno; 
		end;
		
		flag1 = 0;		
		ct = 0;
			
		/* Here it checks each permno and fills out the portfolio arrays */

		do until (ct = maxsize);
			ct + 1;
			idx + 1;
			flag = 0;

			if (&_startdt > currentDate) then leave;
			if (&_enddt < currentDate) then leave;	
		
			do until (flag);
				if(_rets(_initPerms(ct)) > -100) then do;
					if(_excret(_initPerms(ct)) > -100) then do;
						if(_mkt(_initPerms(ct)) ne .) then do;
							_portPerms(idx) = _initPerms(ct);
							_portDates(idx) = currentDate;
							_portRets(idx)  = _rets(_initPerms(ct));
							_portExc(idx)	= _excret(_initPerms(ct));
							_portMkt(idx)	= _mkt(_initPerms(ct));
							_portNum(idx)	= int((ct-1)/&_size) + 1;
							flag = 1;
						end;
					end;
				end;
				
				/* Here randomly selects a new one if the above criteria fails */

				if(_rets(_initPerms(ct)) <= -100) or 
					(_excret(_initPerms(ct)) <= -100) then do;
					do until (flag10 ne 0);
						a = 0;
						do until (a ne 0);
							a = int(ranuni(0)*ct_total);
						end;
						flag10 = 1;
						do x = 1 to &_size;
							chk = int((ct-1)/&_size) + x;
							if _initPerms(chk) = _allPerms(a) then flag10 = 0;
						end;						
					end;

					_initPerms(ct) = _allPerms(a);
				end;
			end;
			
			permno 	= _portPerms(idx);
			date	= _portDates(idx);
			ret	= _portRets(idx);
			exc	= _portExc(idx);
			mkt	= _portMkt(idx);
			portnum	= _portNum(idx);			

			format date date9.;
			format ret exc percentn8.2;
			output;
		end;
	run;

	proc sort data = tempFill out = &_otfile;
		by portnum date;
	run;
	
/*	proc print data = &_otfile;
	run;
	endsas;
*/	
%mend _fillPortArray;

/******************************************************************************
 _Rets calculates the equal weighted and value weighted returns for each period
 in the holding period.
 ******************************************************************************/

%macro _Rets(_infile, _otfile);

	data &_otfile(keep = portnum mo_ew mo_vw exc_ew exc_vw);

		retain portnum ew_ret vw_ret tot_mkt mo_ew mo_vw excew_ret excvw_ret exc_ew exc_vw;

		do until (last.portnum);
			
			set &_infile;
				by portnum date;

			if (first.date) then do;
				ew_ret 		= 0;
				mo_ew 		= 0;
				vw_ret 		= 0;
				mo_vw 		= 0;
				excew_ret	= 0;
				exc_ew		= 0;
				excvw_ret	= 0;
				exc_vw		= 0;
				tot_mkt 	= 0;
				cnt		= 0;
			end;

			tot_mkt 	= tot_mkt + mkt;
			ew_ret 		= ew_ret + ret;
			excew_ret 	= excew_ret + exc;
			vw_ret 		= vw_ret + ret * mkt;
			excvw_ret 	= excvw_ret + exc * mkt;
			cnt + 1;
	
			if (last.date) then do;
				mo_ew 	= ew_ret / cnt;
				mo_vw 	= vw_ret / tot_mkt;
				exc_ew 	= excew_ret / cnt;
				exc_vw 	= excvw_ret / tot_mkt;
				output;
			end;
		end;
	run;

%mend _Rets;

/******************************************************************************
 _calcVariance is the other big part. Here it uses the monthly returns to calc
 the variance and standard deviation for each case.
 ******************************************************************************/

%macro _calcVariance(_infile, _otfile, _hp);
	
	data temp(drop = ct j newport);
	
		array	_ew(1000000)	_temporary_;
		array	_vw(1000000)	_temporary_;
		array 	_excew(1000000)	_temporary_;
		array	_excvw(1000000)	_temporary_;
		
		retain avg_ew avg_vw avg_excew avg_excvw;

		newport = 0;
		do until (last.portnum);
			set &_infile;		
				by portnum;		
	
			if (newport = 0) then do;
				avg_ew		= 0;
				avg_vw		= 0;
				avg_excew	= 0;
				avg_excvw	= 0;
				ct 		= 0;
			end;
			
			newport = 1;
			ct + 1;

			_ew(ct) 	= mo_ew;
			avg_ew 		= avg_ew + mo_ew;

			_vw(ct) 	= mo_vw;
			avg_vw 		= avg_vw + mo_vw;

			_excew(ct) 	= exc_ew;
			avg_excew 	= avg_excew + exc_ew;

			_excvw(ct) 	= exc_vw;
			avg_excvw 	= avg_excvw + exc_vw;

			if(last.portnum) then do;
				avg_vw 		= avg_vw / ct;
				avg_ew 		= avg_ew / ct;
				avg_excew 	= avg_excew / ct;
				avg_excvw 	= avg_excvw / ct;
				portnum		= portnum;
			end;
		end;	
		
		do j = 1 to ct;
			mo_ew 		= _ew(j);
			ew_chng 	= mo_ew - avg_ew;
			ew_sq 		= ew_chng * ew_chng;			

			mo_vw 		= _vw(j);
			vw_chng 	= mo_vw - avg_vw;
			vw_sq 		= vw_chng * vw_chng;

			exc_ew 		= _excew(j);
			excew_chng 	= exc_ew - avg_excew;
			exc_ew_sq 	= excew_chng * excew_chng;
			
			exc_vw 		= _excvw(j);
			excvw_chng 	= exc_vw - avg_excvw;
			exc_vw_sq 	= excvw_chng * excvw_chng;
			
			portnum		= portnum;
			output;
		end;

	run;

	data &_otfile(keep = vw_std ew_std exc_vw_std exc_ew_std portnum);
	
		newport = 0;
		do until (last.portnum);
			set temp;
				by portnum;

			retain vw_stot ew_stot excvw_stot excew_stot;

			if (newport = 0) then do;
				vw_stot 	= 0;
				ew_stot 	= 0;
				excvw_stot 	= 0;
				excew_stot 	= 0;
			end;
			newport = 1;

			vw_stot 		= vw_stot + vw_sq;
			ew_stot 		= ew_stot + ew_sq;
			excvw_stot 		= excvw_stot + exc_vw_sq;
			excew_stot 		= excew_stot + exc_ew_sq;

			if (last.portnum) then do;
				vw_var 		= vw_stot /  (&_hp - 1);
				vw_std 		= sqrt(vw_var);

				ew_var 		= ew_stot / (&_hp - 1);
				ew_std 		= sqrt(ew_var);

				exc_vw_var 	= excvw_stot / (&_hp - 1);
				exc_vw_std 	= sqrt(exc_vw_var);

				exc_ew_var 	= excew_stot / (&_hp - 1);
				exc_ew_std 	= sqrt(exc_ew_var);

				output;
			end;
		end;
	run;
	
%mend _calcVariance;

/******************************************************************************
 _addLocal just appends the "local" data set to a full data set. "Local" means
 that it is the same repition of a portfolio of the same size.
 ******************************************************************************/

%macro _addLocal(_infile, _base);

	proc append base = &_base data = &_infile;
	run;

%mend _addLocal;

/******************************************************************************
 _addMacro finds the average of the local data sets and uses that as the over all
 standard deviation for the portfolio of that size.
 ******************************************************************************/

%macro _addMacro(_infile, _base, _size, _reps, _start);

	data temp(keep = ewstd vwstd exc_ewstd exc_vwstd reps size startDate);

		set &_infile end = eof;
		
		retain ct vw_std_tot ew_std_tot exc_ew_tot exc_vw_tot;

		if (_n_ = 1) then do;
			ct = 0;
			vw_std_tot 	= 0;
			ew_std_tot 	= 0;
			exc_ew_tot	= 0;
			exc_vw_tot	= 0;
		end;
		
		ct + 1;

		vw_std_tot 		= vw_std_tot + vw_std;
		ew_std_tot 		= ew_std_tot + ew_std;
		exc_ew_tot 		= exc_ew_tot + exc_ew_std;
		exc_vw_tot 		= exc_vw_tot + exc_vw_std;


		if (eof) then do;
			size 		= &_size;
			reps 		= &_reps;
			startDate 	= &_start;

			format startDate year4.;

			ewstd 		= ew_std_tot / ct;
			vwstd 		= vw_std_tot / ct;
			exc_ewstd	= exc_ew_tot / ct;
			exc_vwstd	= exc_vw_tot / ct;

	
			format ewstd vwstd exc_ewstd exc_vwstd percentn8.2;
	
			output;
		end;
	run;

	proc append base = &_base data = temp;
	run;

%mend _addMacro;

