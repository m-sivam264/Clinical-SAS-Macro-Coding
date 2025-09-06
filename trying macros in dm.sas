/********************************TRYINNG MACROS********************************************/
/*CONVERTING DATE VALUES TO REQUIRED NUMBER FORMATS */

libname RAWDATA 'D:\Clinical_Projects\Domains_Learn\Classes\RAW';
libname practice 'D:\Clinical_Projects\Domains_Learn\Classes\DM\practice';

%macro dateconversion (new=,old=,dat=);
	
		data practice.&new;
		    set rawdata.&old;
		   			USUBJID = catx('-', STUDY, PT);
		            dt_num = input(tranwrd(strip(&dat), '/', ''), date11.);

		    keep study pt USUBJID &dat dt_num;
		run;

		proc sort data = practice.&new;
			by USUBJID;
		run;
%mend;

%dateconversion (new=Adverse_dates, old=Adverse, dat = AEENDT_RAW);
%dateconversion (new=Eos_dates, old=eos, dat = EOSTDT_RAW);
%dateconversion (new=Conmeds_dates, old=Conmeds, dat = CMENDT_RAW);
%dateconversion (new=ecg_dates, old=ecg, dat = EGDT_RAW);
%dateconversion (new=enrlment1_dates, old=enrlment, dat = ICDT_RAW);
%dateconversion (new=enrlment2_dates, old=enrlment, dat = ENRLDT_RAW);
%dateconversion (new=enrlment3_dates, old=enrlment, dat = RANDDT_RAW);
%dateconversion (new=eoip_dates, old=eoip, dat = EOSTDT_RAW);
%dateconversion (new=eq5d3l_dates, old=eq5d3l, dat = DT_RAW);
%dateconversion (new=ipadmin_dates, old=ipadmin, dat = IPSTDT_RAW);
%dateconversion (new=lab_chem_dates, old=lab_chem, dat = LBDT_RAW);
%dateconversion (new=lab_hema_dates, old=lab_hema, dat = LBDT_RAW);
%dateconversion (new=Physmeas_dates, old=Physmeas, dat = PMDT_RAW);
%dateconversion (new=Surg_dates, old=Surg, dat = SURGDT_RAW);
%dateconversion (new=vitals_dates, old=vitals, dat = VSDT_RAW);

data practice.DM;
	
	RETAIN STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC DTHDTC DTHFL SITEID 
			AGE AGEU SEX RACE ETHNIC
			ARMCD ARM ACTARMCD ACTARM COUNTRY DMDTC DMDY ;

	set practice.TWELVE;

	label STUDYID = 'Study Identifier'
			DOMAIN = 'Domain Abbreviation'
			USUBJID = 'Unique Subject Identifier'
			SUBJID = 'Subject Identifier for the Study'
			RFSTDTC = 'Subject Reference Start Date/Time'
			RFENDTC = 'Subject Reference End Date/Time'
			RFXSTDTC = 'Date/Time of First Study Treatment'
			RFXENDTC = 'Date/Time of Last Study Treatment'
			RFICDTC = 'Date/Time of Informed Consent'
			RFPENDTC = 'Date/Time of End of Participation'
			DTHDTC = 'Date/Time of Death'
			DTHFL = 'Subject Death Flag'
			SITEID = 'Study Site Identifier'
			AGE = 'Age'
			AGEU = 'Age Units'
			SEX = 'Sex'
			RACE = 'Race'
			ETHNIC = 'Ethnicity'
			ARMCD = 'Planned Arm Code'
			ARM = 'Description of Planned Arm'
			ACTARMCD = 'Actual Arm Code'
			ACTARM = 'Description of Actual Arm'
			COUNTRY = 'Country'
			DMDTC = 'Date/Time of Collection'
			DMDY = 'Study Day of Collection';
	
run;

%macro datcon(var=);
    input(compress(strip(&var), '/'), date11.)
%mend datcon;


proc sql;
	create table practice.DTHDTC as select USUBJID, DTHDTC_NUM, put(DTHDTC_NUM, e8601da10.) as DTHDTC, DTHFL
		from (
			select  catx('-', STUDY, PT) as USUBJID,
			%datcon(var=EOSTDT_RAW) as DTHDTC_NUM, /* CALLING DATCON macro*/
			'Y' as DTHFL
			from rawdata.Eos 
			where EOSCAT = "End of Study" and EOTERM = "Death"
			);
quit;



data practice.RFICDTC;
    set rawdata.Enrlment;

    USUBJID = catx('-', STUDY, PT);

    RFICDTC_NUM = %datcon(var=ICDT_RAW);
    RFICDTC = put(RFICDTC_NUM, e8601da10.);

    keep USUBJID RFICDTC_NUM RFICDTC;
run;


data practice.DM2;
	set rawdata.Ipadmin;
	
	if IPQTY_RAW > 0;
	
	IPSTDT = %datcon(var=IPSTDT_RAW); /* CALLING DATCON macro*/

	IPSTTM_NUM = input(strip(IPSTTM_RAW), time5.);

	IPSTDT_TM_num = dhms(IPSTDT, hour(IPSTTM_num), minute(IPSTTM_num), second(IPSTTM_num));

	RFXSTDTC = put (IPSTDT_TM_NUM, E8601DT19.); 

	keep STUDY PT IPSTDT IPSTTM_NUM IPSTDT_TM_num RFXSTDTC;
run;
proc print;
run;

data practice.RFENDDTC;
	set rawdata.Eos;
	
	USUBJID = STUDY || '-' || PT ;
	if EOSCAT = 'End of Study' then do;
	RFENDTC_NUM = %datcon(var=EOSTDT_RAW);;
	RFENDTC = put(RFENDTC_NUM, E8601DA10.);
	end;

	keep USUBJID RFENDTC;
proc print;
run;


/****************************************************************************/

%macro dsmerge(new=, old_1=, old_2=, var=);
	
	proc sort data = practice.&old_1;
		by &var;
	run;

	proc sort data = practice.&old_2;
		by &var;
	run;

	
	data practice.&new;
		merge practice.&old_1 (in = a)
			practice.&old_2 (in = b);
			
		by &var;

		if a;
	run;
%mend dsmerge;

/*1. adding RFXSTDTC*/
%dsmerge (new = ONE, old_1 = DM1, old_2 = DM3, var = USUBJID);

/* 2. adding RFSTDTC */

data practice.TWO;
	set practice.ONE;

	if not missing (RFXSTDTC) then do;
	RFSTDTC = scan(RFXSTDTC,1,'T');
	end;
proc print;
run;


/* for missing RFSTDTC values*/

data practice.ENRLMENT;
	set rawdata.Enrlment;

	USUBJID = catx('-', STUDY, PT);
	randdate_num = input(tranwrd(strip(RANDDT_RAW), '/', ''), date11.);

	keep USUBJID RANDDT_RAW randdate_num;
proc print;
run;

proc sort data = practice.Enrlment; by USUBJID; run;

data practice.THREE;
	merge practice.TWO (in = a)
		practice.ENRLMENT (in = b);
	by USUBJID;

	if missing(RFSTDTC) then do;
		RFSTDTC = put(randdate_num, E8601DA10.);
	end;
	drop randdate_num RANDDT_RAW;
proc print;
run;


/*3. adding RFENDTC*/

%dsmerge (new = FOUR, old_1 = THREE, old_2 = RFENDDTC, var = USUBJID);

/*4. adding RFXENDDTC*/

%dsmerge (new = FIVE, old_1 = FOUR, old_2 = DM4, var = USUBJID);

/*5. adding RFICDTC*/

%dsmerge (new = SIX, old_1 = FIVE, old_2 = RFICDTC, var = USUBJID);

			/*IF RFSTDTC IS NULL THEN TAKEN FROM RFICDTC */
data practice.SEVEN;
	set practice.SIX;

	if RFSTDTC = . then RFSTDTC = RFICDTC;
proc print;
run;

/* 7. adding RFPENDTC*/
%dsmerge (new = EIGHT, old_1 = SEVEN, old_2 = RFPENDTC, var = USUBJID);

/*8. adding DTHDTC, DTHFL*/
%dsmerge (new = NINE, old_1 = EIGHT, old_2 = DTHDTC, var = USUBJID);

/*9. adding ARMCD, ARM*/
%dsmerge (new = TEN, old_1 = NINE, old_2 = ARMCD, var = USUBJID);

/*10. adding ACTARMCD, ACTARM */
%dsmerge (new = ELEVEN, old_1 = TEN, old_2 = BOXKITID, var = USUBJID);

/*11. adding DMDTC & DMDY */
/*if dmdtc greater than or equal to rfstdtc then dmdtc-rfstdtc+1 else dmdtc-rfstdtc*/

proc sort data = practice.DMDTC; by USUBJID; run;

data practice.TWELVE;
	merge practice.ELEVEN (in = a)
		practice.DMDTC (in = b);
	by USUBJID;
	if a;
	
	DMDTC_NUM = input(DMDTC, E8601DA10.);
	RFSTDTC_NUM = input(RFSTDTC, E8601DA10.);

	if DMDTC >= RFSTDTC then DMDY = DMDTC_NUM - RFSTDTC_NUM + 1;
	else DMDY = DMDTC_NUM - RFSTDTC_NUM;
	
	drop DMDTC_NUM RFSTDTC_NUM;
proc print;
run;


