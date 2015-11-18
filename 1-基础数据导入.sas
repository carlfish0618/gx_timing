/*** 每日运行程序 **/
options validvarname=any; /* 支持中文变量名 */


%LET timing_path = D:\Carl\Research\GIT-BACKUP\国信择时模型;
LIBNAME timing "&timing_path.\sasdata";
%LET input_path = &timing_path.\input_data;
%LET output_path = &timing_path.\output_data;


%LET utils_dir = D:\Carl\Research\GIT-BACKUP\utils\SAS\修改版本; 
%INCLUDE "&utils_dir.\日期_通用函数.sas";
%INCLUDE "&utils_dir.\其他_通用函数.sas";
%INCLUDE "&utils_dir.\计量_通用函数.sas";


%read_from_excel(excel_path=&input_path.\申万行业行情数据.xlsx, output_table=timing.idx_ret, sheet_name = return$);
%read_from_excel(excel_path=&input_path.\申万行业行情数据.xlsx, output_table=timing.mapping, sheet_name = mapping$);
%read_from_excel(excel_path=&input_path.\申万行业行情数据.xlsx, output_table=timing.hs300, sheet_name = hs300$);
%read_from_excel(excel_path=&input_path.\申万行业行情数据.xlsx, output_table=timing.risk_free_rate, sheet_name = 国债到期收益率$);


/** 对行业指数行情进行转置和处理 */
PROC TRANSPOSE DATA = timing.idx_ret OUT = idx_ret;
	BY end_date;
RUN;
DATA idx_ret;
	SET idx_ret;
	_NAME_ = substr(_NAME_,1,6);
	RENAME _NAME_ = sw_code;
	LABEL _NAME_ = "sw_code";
	RENAME COL1 = close;
	LABEL COL1 = "close";
	DROP _LABEL_;
RUN;

/** 对基准指数行情进行转置和处理 */
PROC TRANSPOSE DATA = timing.hs300 OUT = hs300;
	BY end_date;
RUN;
DATA hs300;
	SET hs300;
	RENAME _NAME_ = index_code;
	LABEL _NAME_ = "index_code";
	RENAME COL1 = close;
	LABEL COL1 = "close";
	DROP _LABEL_;
RUN;


/** 对映射进行处理 */
DATA mapping;
	SET timing.mapping;
	sw_code = substr(sw_code,1,6);
	IF not missing(sw_code);
RUN;

