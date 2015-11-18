/*** 构建模型 **/

/********************** Step1:计算周度收益 */
/** Step1-1: 周日期序列 */
PROC SQL;
	CREATE TABLE week_date AS
	SELECT distinct end_date
	FROM idx_ret
	ORDER BY end_date;
QUIT;
DATA week_date;
	SET week_date;
	id = _N_;
RUN;

/** Step1-2: 申万一级行业指数周收益 */
PROC SQL;
	CREATE TABLE tmp AS
	SELECT A.*, 
	D.close AS pre_close LABEL "pre_close"
	FROM idx_ret A LEFT JOIN week_date B
	ON A.end_date = B.end_date
	LEFT JOIN week_date C
	ON B.id = C.id + 1
	LEFT JOIN idx_ret D
	ON D.end_date = C.end_date AND D.sw_code = A.sw_code
	ORDER BY A.end_date, A.sw_code;
QUIT;
DATA idx_ret;
	SET tmp;
	IF not missing(pre_close) AND not missing(close) THEN rtn = (close/pre_close-1)*100;
	ELSE rtn = .;
RUN;

/** Step1-3: 市场指数(沪深300)周收益 */
PROC SQL;
	CREATE TABLE tmp AS
	SELECT A.*, 
	D.close AS pre_close LABEL "pre_close"
	FROM hs300 A LEFT JOIN week_date B
	ON A.end_date = B.end_date
	LEFT JOIN week_date C
	ON B.id = C.id + 1
	LEFT JOIN hs300 D
	ON D.end_date = C.end_date AND D.index_code = A.index_code
	ORDER BY A.end_date, A.index_code;
QUIT;
DATA hs300;
	SET tmp;
	IF not missing(pre_close) AND not missing(close) THEN rtn = (close/pre_close-1)*100;
	ELSE rtn = .;
RUN;

/** Step1-4: 将无风险收益变为周度日期 */
%adjust_date_to_mapdate(rawdate_table=timing.risk_free_rate, mapdate_table=week_date, 
	raw_colname=end_date, map_colname=end_date, output_table=risk_free_rate,is_backward=0, is_included=1);
/* 保留每个周末的最后一天结果作为该周的rf*/
PROC SQL;
	CREATE TABLE tmp AS
	SELECT map_end_date AS end_date LABEL "end_date",
	end_date AS daily_date LABEL "daily_date",
	y3,y10
	FROM risk_free_rate
	WHERE not missing(map_end_date)
	GROUP BY map_end_date
	HAVING daily_date=max(daily_date);
QUIT;
DATA risk_free_rate;
	SET tmp;
RUN;

/** Step1-5：将市场指数收益和无风险收益率增加至idx_ret中，用于估计beta */
PROC SQL;
	CREATE TABLE merge_ret AS
	SELECT A.end_date, 
	A.sw_code,
	A.rtn AS rtn,
	B.rtn AS bm_rtn,
	C.y10 AS rf
	FROM idx_ret A LEFT JOIN hs300 B
	ON A.end_date = B.end_date AND B.index_code = "hs300"
	LEFT JOIN risk_free_rate C
	ON A.end_date = C.end_date
	ORDER BY A.end_date, A.sw_code;
QUIT;
DATA merge_ret;
	SET merge_ret;
	rtn_adj = rtn - rf;
	bm_rtn_adj = bm_rtn - rf;
	IF not missing(rtn_adj) AND not missing(bm_rtn_adj);
RUN;


/********************* Step2: 计算beta值 **/
/** Step2-1: 构造每次滚动计算的样本时间，间隔100周 */
PROC SQL;
	CREATE TABLE ols_time AS
	SELECT P.sw_code,Q.*
	FROM
	(
		SELECT distinct sw_code
		FROM idx_ret) P,
	(
		SELECT A.end_date AS start_date LABEL "start_date",
		B.end_date AS end_date LABEL "end_date"
		FROM week_date A LEFT JOIN week_date B
		ON A.id = B.id - 99
		WHERE not missing(B.end_date)
	) Q
	ORDER BY P.sw_code,Q.end_date;
QUIT;


/** Step2-2: CAPM模型估计beta */
DATA timing.ols_result;
	ATTRIB
		sw_code LENGTH = $6
		start_date LENGTH =8
		end_date LENGTH = 8
		alpha LENGTH = 8
		alpha_p LENGTH = 8
		alpha_se LENGTH = 8
		beta LENGTH = 8
		beta_p LENGTH = 8
		beta_se LENGTH = 8
		rmse LENGTH = 8
		rsquare LENGTH = 8
		n_data LENGTH = 8;
	STOP;
	FORMAT start_date end_date yymmdd10.;
RUN;

ODS LISTING CLOSE;
/*%LET ret_table = merge_ret;*/
/*%LET start_date = "11jan2004"d;*/
/*%LET end_date = "15jan2006"d;*/
/*%LET ret_col = rtn_adj;*/
/*%LET bm_ret_col = bm_rtn_adj;*/
/*%LET sw_code = 801010;*/

%MACRO rolling_ols_beta(sw_code, start_date, end_date, ret_table, ret_col=rtn_adj, bm_ret_col=bm_rtn_adj);	
 	/*close listing */
	ODS OUTPUT ParameterEstimates = estimates;
	PROC REG DATA = &ret_table. OUTEST = _outset_ds rsquare;
		WHERE  &start_date.<= end_date <= &end_date. and sw_code = "&sw_code.";
		MODEL &ret_col. = &bm_ret_col.;
	QUIT;
	
	PROC SQL NOPRINT;
		CREATE TABLE tmp AS
			SELECT "&sw_code." AS sw_code, 
			&start_date. AS start_date FORMAT yymmdd10., 
			&end_date. AS end_date FORMAT yymmdd10.,
			rsquare, rmse, 
			beta, beta_p, beta_se, 
			alpha, alpha_p, alpha_se,n_data
			FROM (
				SELECT _RSQ_ AS rsquare, 
				_RMSE_ AS rmse, 
				_EDF_+2 AS n_data
				 FROM _outset_ds),
				(
				SELECT estimate AS beta, 
				probt AS beta_p, 
				stderr AS beta_se
				FROM estimates
				WHERE variable = "&bm_ret_col."),
				(
				SELECT estimate AS alpha, 
				probt AS alpha_p, 
				stderr AS alpha_se
				FROM estimates
				WHERE variable = "Intercept");
	QUIT;

	PROC DATASETS NOLIST;
		APPEND BASE = timing.ols_result DATA = tmp force;
	RUN;
	
	PROC SQL;
		DROP TABLE tmp, _outset_ds, estimates;
	QUIT;	
%MEND rolling_ols_beta;

/*%rolling_ols_beta(sw_code=801010, start_date="11jan2004"d, end_date="8jan2006"d, */
/*	ret_table=merge_ret, ret_col=rtn_adj, bm_ret_col=bm_rtn_adj);*/

FILENAME myfile10 'D:\Carl\mylog22.log';
FILENAME myfile20 'D:\Carl\myoutput22.lst';
PROC PRINTTO LOG =myfile10 PRINT= myfile20;
RUN;

DATA _NULL_;
	SET ols_time;
	IF "31dec2004"d < end_date <= "30jun2005"d THEN 
	CALL EXECUTE('%rolling_ols_beta(sw_code = '||sw_code||', start_date = '||start_date||', end_date = '||end_date||',
	ret_table = merge_ret)');
RUN;

PROC PRINTTO LOG = log PRINT = print;
RUN;

ODS LISTING;
/*PROC SQL;*/
/*	CREATE TABLE tmp AS*/
/*	SELECT end_date, count(1)*/
/*	FROM timing.ols_result*/
/*	group by end_date;*/
/*QUIT;*/

/** 临时将分次结果拼凑起来 */
DATA timing.ols_result_all;
	SET timing.ols_result2005_2009 
		timing.ols_result2010
		timing.ols_result2011
		timing.ols_result2012_2013
		timing.ols_result2014
		timing.ols_result2015;
RUN;

/*** Step3: 计算择时信号 */
/*** Step3-1: 计算beta的Spearman相关系数 */
/** 拼接下个月的return */
PROC SQL;
	CREATE TABLE tmp AS
	SELECT A.*, C.end_date AS next_date FORMAT yymmdd10. LABEL "next_date"
	FROM timing.ols_result_all A LEFT JOIN week_date B
	ON A.end_date = B.end_date 
	LEFT JOIN week_date C
	ON C.id = B.id + 1
	WHERE not missing(C.end_date);
QUIT;
PROC SQL;
	CREATE TABLE ols_result_all AS
	SELECT A.*, B.rtn 
	FROM tmp A LEFT JOIN idx_ret B
	ON A.next_date = B.end_date AND A.sw_code = B.sw_code
	ORDER BY A.next_date, A.sw_code;
QUIT;

%cal_coef(data=ols_result_all, var1=rtn, var2=beta, output_s = corr_s, output_p = corr_p);
DATA gsisi;
	SET corr_s;
	gsisi = 100*s_ic;
	IF gsisi >= 31.7 THEN signal = 1;
	ELSE IF gsisi <= -31.7 THEN signal = -1;
	ELSE signal = 0;
RUN;

/** Step3-2: 确定择时信号和买卖状态 */
/** 要求连续两次signal = 1出现买入信号，连续两次signal=-1出现卖出信号。若没有信号则维持原有状态 */
DATA gsisi(drop = last_signal last_status);
	SET gsisi;
	RETAIN status 0;
	RETAIN last_signal 0 ;
	RETAIN last_status 0;
	operation = 0;

	IF signal = 1 AND last_signal = 1 THEN status = 1;
	ELSE IF signal = -1 AND last_signal = -1 THEN status = 0;

	IF status = 1 AND last_status = 0 THEN operation = 1;  /* 出现买入 */
	ELSE IF status = 0 AND last_status = 1 THEN operation = -1; /* 出现卖出 */
	last_signal = signal;
	last_status = status;	
RUN;
