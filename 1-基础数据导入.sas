/*** ÿ�����г��� **/
options validvarname=any; /* ֧�����ı����� */


%LET timing_path = D:\Carl\Research\GIT-BACKUP\������ʱģ��;
LIBNAME timing "&timing_path.\sasdata";
%LET input_path = &timing_path.\input_data;
%LET output_path = &timing_path.\output_data;


%LET utils_dir = D:\Carl\Research\GIT-BACKUP\utils\SAS\�޸İ汾; 
%INCLUDE "&utils_dir.\����_ͨ�ú���.sas";
%INCLUDE "&utils_dir.\����_ͨ�ú���.sas";
%INCLUDE "&utils_dir.\����_ͨ�ú���.sas";


%read_from_excel(excel_path=&input_path.\������ҵ��������.xlsx, output_table=timing.idx_ret, sheet_name = return$);
%read_from_excel(excel_path=&input_path.\������ҵ��������.xlsx, output_table=timing.mapping, sheet_name = mapping$);
%read_from_excel(excel_path=&input_path.\������ҵ��������.xlsx, output_table=timing.hs300, sheet_name = hs300$);
%read_from_excel(excel_path=&input_path.\������ҵ��������.xlsx, output_table=timing.risk_free_rate, sheet_name = ��ծ����������$);


/** ����ҵָ���������ת�úʹ��� */
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

/** �Ի�׼ָ���������ת�úʹ��� */
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


/** ��ӳ����д��� */
DATA mapping;
	SET timing.mapping;
	sw_code = substr(sw_code,1,6);
	IF not missing(sw_code);
RUN;

