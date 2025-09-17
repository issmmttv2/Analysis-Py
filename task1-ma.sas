PROC IMPORT OUT=targets 
    DATAFILE="Targets.xlsx" 
    DBMS=XLSX REPLACE;
    GETNAMES=YES;
RUN;

PROC IMPORT OUT=firm_data 
    DATAFILE="Firm_data.xlsx" 
    DBMS=XLSX REPLACE;
    GETNAMES=YES;
RUN;

PROC SORT DATA=targets NODUPKEY;
    BY cusip6 ann_date;
RUN;

PROC SORT DATA=firm_data NODUPKEY;
    BY cusip6 fyear;
RUN;

DATA targets;
    SET targets;
    fyear = YEAR(ann_date) - 1;
RUN;

PROC SQL;
    CREATE TABLE merged AS
    SELECT a.*,
           COALESCE(b.target_value, .) AS target_value,
           COALESCE(b.target_name, '') AS target_name,
           CASE WHEN b.cusip6 IS NOT NULL THEN 1 ELSE 0 END AS target
    FROM firm_data AS a
    LEFT JOIN targets AS b
    ON a.cusip6 = b.cusip6 AND a.fyear = b.fyear;
QUIT;

DATA merged;
    SET merged;
    sic1 = FLOOR(sic4 / 1000);
RUN;

%MACRO winsorize(ds=, var=);
    PROC UNIVARIATE DATA=&ds NOPRINT;
        VAR &var;
        OUTPUT OUT=tmp_pctl P1=p1 P99=p99;
    RUN;

    DATA &ds;
        SET &ds;
        IF _N_=1 THEN SET tmp_pctl;
        IF &var < p1 THEN &var = p1;
        ELSE IF &var > p99 THEN &var = p99;
    RUN;

    PROC DELETE DATA=tmp_pctl;
    RUN;
%MEND winsorize;

%winsorize(ds=merged, var=at);
%winsorize(ds=merged, var=sale);
%winsorize(ds=merged, var=div_at);
%winsorize(ds=merged, var=payout_at);
%winsorize(ds=merged, var=ret);
%winsorize(ds=merged, var=sale_gr);
%winsorize(ds=merged, var=assets_gr);
%winsorize(ds=merged, var=mb);
%winsorize(ds=merged, var=roa);
%winsorize(ds=merged, var=profit_margin);
%winsorize(ds=merged, var=debt_at);
%winsorize(ds=merged, var=cash_at);
%winsorize(ds=merged, var=rd_at);
%winsorize(ds=merged, var=capex_at);
%winsorize(ds=merged, var=nppe_at);

PROC MEANS DATA=merged N NMISS MIN MAX MEAN STD MEDIAN;
    VAR target at sale div_at payout_at ret sale_gr assets_gr mb roa profit_margin debt_at cash_at rd_at capex_at nppe_at;
    OUTPUT OUT=summary_stats;
RUN;

PROC EXPORT DATA=summary_stats 
    OUTFILE="summary_stats.xlsx" 
    DBMS=XLSX REPLACE;
RUN;

PROC FREQ DATA=merged;
    TABLES fin_d util_d loss_d sic1 sic4 state / NOCUM NOPERCENT;
RUN;

PROC GCHART DATA=merged;
    PIE sic1 / SUMVAR=target TYPE=PERCENT;
    TITLE "Pie Chart: Proportion of M&A Targets by Industry (SIC1)";
RUN;

PROC SGPLOT DATA=merged;
    HISTOGRAM at;
    TITLE "Histogram: Distribution of Total Assets";
RUN;

PROC SGPLOT DATA=merged;
    SCATTER X=roa Y=mb;
    TITLE "Scatter Plot: ROA vs Market-to-Book Ratio";
RUN;

PROC SGPLOT DATA=merged;
    VBOX roa / CATEGORY=target;
    TITLE "Box Plot: ROA by Target Status";
RUN;

PROC CORR DATA=merged;
    VAR at sale div_at payout_at ret sale_gr assets_gr mb roa profit_margin debt_at cash_at rd_at capex_at nppe_at;
RUN;

