--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: labs; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

DROP TABLE IF EXISTS gen.labs;
CREATE TABLE gen.labs (
    code character varying,
    label text,
    freq real,
    loinc character varying,
    loinc_name text,
    loinc_short_name text,
    units text,
    range_min double precision,
    range_max double precision,
    range_units text
);


--
-- Data for Name: labs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY gen.labs (code, label, freq, loinc, loinc_name, loinc_short_name, units, range_min, range_max, range_units) FROM stdin;
EOC	EOSINOPHIL PERCENT	0.0248565525	713-8	Eosinophils/100 leukocytes in Blood by Automated count	Eosinophil NFr Bld Auto	%	\N	\N	%
CL	CHLORIDE	0.0255078152	2075-0	Chloride [Moles/volume] in Serum or Plasma	Chloride SerPl-sCnc	mmol/L	98	106	mmol/L
PRUR	PROTEIN,RANDOM URINE	9.33333358e-05	2888-6	Protein [Mass/volume] in Urine	Prot Ur-mCnc	g/dL	\N	\N	g/dL
FTI	FREE THYROXINE INDEX (LAB)	0.000273908052	3022-1	Deprecated Thyroxine free index in Serum or Plasma	Deprecated FTI SerPl-mCnc	ug/dL	\N	\N	ug/dL
CKMBPCT	CREATINE KINASE REL INDEX	0.000152643683	12189-7	Creatine kinase.MB/Creatine kinase.total in Serum or Plasma by calculation	CK MB CFr SerPl Calc	%	\N	\N	%
LYMPH	LYMPHOCYTES	0.00431689667	20585-6	Lymphocytes [#/volume] in Unspecified specimen by Automated count	Lymphocytes # XXX Auto	10*3/uL	\N	\N	10*3/uL
LACT2	LACTIC ACID (mmol/L)	0.000301954016	2518-9	Lactate [Moles/volume] in Arterial blood	Lactate BldA-sCnc	mmol/L	\N	\N	mmol/L
*OGTT5C	COMMENT	3.44827583e-07	8251-1	Service comment	Service Cmnt XXX-Imp	\N	\N	\N	\N
UCAOX	CALCIUM OXALATE	0.000122068966	25148-8	Calcium oxalate crystals [#/area] in Urine sediment by Microscopy high power field	CaOx Cry #/area UrnS HPF	/[HPF]	\N	\N	/[HPF]
GLUF	GLUCOSE-FAST	0.000110459769	1558-6	Fasting glucose [Mass/volume] in Serum or Plasma	Glucose p fast SerPl-mCnc	mg/dL	\N	\N	mg/dL
CKMB	CREATINE KINASE-MB	0.000444367819	13969-1	Creatine kinase.MB [Mass/volume] in Serum or Plasma	CK MB SerPl-mCnc	ng/mL	\N	\N	ng/mL
LAP	LEUKOCYTE ALK PHOS	1.51724134e-05	4659-9	Leukocyte phosphatase [Enzymatic activity/volume] in Leukocytes	LAP WBC-cCnc	\N	\N	\N	\N
UOBX	URINE OCCULT BLOOD	2.2988506e-07	5794-3	Hemoglobin [Presence] in Urine by Test strip	Hgb Ur Ql Strip	\N	\N	\N	\N
FL	FLUID LYMPHS	0.000131609195	11031-2	Lymphocytes/100 leukocytes in Body fluid	Lymphocytes NFr Fld	%	\N	\N	%
BAND	BANDS	0.00340367807	26510-8	Neutrophils.band form/100 leukocytes in Body fluid	Neuts Band NFr Fld	%	\N	\N	%
MYELO	MYELOCYTE	0.000256896543	26498-6	Myelocytes/100 leukocytes in Blood	Myelocytes NFr Bld	%	\N	1	%
ESTRA	ESTRADIOL	8.78160936e-05	2243-4	Estradiol (E2) [Mass/volume] in Serum or Plasma	Estradiol SerPl-mCnc	pg/mL	\N	\N	pg/mL
UGLX	URINE GLUCOSE	2.2988506e-07	20406-5	Deprecated Glucose [Mass/volume] in Urine by Test strip	Deprecated Glucose Fr Ur Strip	%	\N	\N	%
*%HBA1C	% HEMOGLOBIN A1C	0.00172459765	4548-4	Hemoglobin A1c/Hemoglobin.total in Blood	Hgb A1c MFr Bld	%	3.79999999999999982	6.40000000000000036	%
EVER	EVEROLIMUS (CERTICAN)	2.2988506e-07	50544-6	Everolimus [Mass/volume] in Blood	Everolimus Bld-mCnc	ng/mL	\N	\N	ng/mL
BILD	BILIRUBIN,DIRECT	0.00246172422	14630-8	Bilirubin.indirect [Moles/volume] in Serum or Plasma	Bilirub Indirect SerPl-sCnc	umol/L	\N	\N	umol/L
ACET	ACETONE BLOOD	0.000115517243	39529-3	Acetone [Presence] in Blood	Acetone Bld Ql	\N	\N	\N	\N
UBILX	URINE BILIRUBIN	1.1494253e-07	1977-8	Bilirubin.total [Presence] in Urine	Bilirub Ur Ql	\N	\N	\N	\N
UAPP	URINE APPEARANCE	0.00922965538	5767-9	Appearance of Urine	Appearance Ur	\N	\N	\N	\N
LACT1	LACTIC ACID (mg/dL)	0.000301954016	2518-9	Lactate [Moles/volume] in Arterial blood	Lactate BldA-sCnc	mmol/L	\N	\N	mmol/L
RA	RHEUMATOID FACTOR	0.00021965518	11572-5	Rheumatoid factor [Units/volume] in Serum or Plasma	Rheumatoid fact SerPl-aCnc	[IU]/mL	\N	\N	[IU]/mL
FP	FLUID POLYS	0.000124367813	26518-1	Polymorphonuclear cells/100 leukocytes in Body fluid	Polys NFr Fld	%	\N	\N	%
GOB	GASTRIC OCCULT BLOOD	1.1494253e-07	2334-1	Hemoglobin.gastrointestinal [Presence] in Gastric fluid	Gastrocult Gast Ql	\N	\N	\N	\N
PMOR	PLATELET MORPHOLOGY	5.03448282e-05	9317-9	Platelet adequacy [Presence] in Blood by Light microscopy	Platelet Bld Ql Smear	\N	\N	\N	\N
*FFATQT	FECAL FAT QUANTITATIVE	2.2988506e-07	16142-2	Fat [Mass/time] in 24 hour Stool	Fat 24h Stl-mRate	g/(24.h)	\N	\N	g/(24.h)
GLU	GLUCOSE	0.0254971273	2345-7	Glucose [Mass/volume] in Serum or Plasma	Glucose SerPl-mCnc	mg/dL	74	106	mg/dL
UAMB	AMMONIUM BIURATE	1.26436782e-06	25144-7	Ammonium urate crystals [#/area] in Urine sediment by Microscopy high power field	Amm Urate Cry #/area UrnS HPF	/[HPF]	\N	\N	/[HPF]
SPHR	SPHEROCYTES	0.000227471261	802-9	Spherocytes [Presence] in Blood by Light microscopy	Spherocytes Bld Ql Smear	\N	\N	\N	\N
FCOM	FLUID COMMENT	4.12643676e-05	8251-1	Service comment	Service Cmnt XXX-Imp	\N	\N	\N	\N
CREAUR	CREATININE,RANDOM URINE	0.000208735626	2161-8	Creatinine [Mass/volume] in Urine	Creat Ur-mCnc	mg/dL	\N	\N	mg/dL
APINEAPPLE	ALLERGEN,PINEAPPLE	1.1494253e-07	6218-2	Pineapple IgE Ab [Units/volume] in Serum	Pineapple IgE Qn	k[IU]/L	\N	\N	k[IU]/L
WS	WRIGHT STAIN	4.27586201e-05	681-7	Microscopic observation [Identifier] in Unspecified specimen by Wright stain	Wright Stn XXX	\N	\N	\N	\N
*BORDIGGI	B.PERTUSSIS IGG IMMUNOBLOT	5.74712658e-07	29674-9	Bordetella pertussis IgG Ab [Presence] in Serum	B pert IgG Ser Ql	\N	\N	\N	\N
OSMOS	OSMOLALITY-SERUM	8.49425269e-05	2692-2	Osmolality of Serum or Plasma	Osmolality SerPl	mosm/kg	\N	\N	mosm/kg
*TVUNU	TOTAL VOLUME	1.14942532e-06	3169-0	Volume of Unspecified specimen	Specimen vol XXX	mL	\N	\N	mL
AMY	AMYLASE	0.000640229904	1798-8	Amylase [Enzymatic activity/volume] in Serum or Plasma	Amylase SerPl-cCnc	U/L	\N	\N	U/L
*MICALB1	MICROALBUMIN - mg/dL	0.000302298839	14957-5	Microalbumin [Mass/volume] in Urine	Microalbumin Ur-mCnc	mg/dL	\N	20	mg/dL
TETANUS	TETANUS IGG ANTIBODY	2.2988506e-07	6367-7	Clostridium tetani IgG Ab [Units/volume] in Serum by Immunoassay	C tetani IgG Ser EIA-aCnc	{Index_val}	\N	\N	{Index_val}
AMM	AMMONIA	0.00023333334	1841-6	Ammonia [Moles/volume] in Serum	Ammonia Ser-sCnc	umol/L	\N	\N	umol/L
ESRW	SED RATE WESTERGREN	0.00115045975	4537-7	Erythrocyte sedimentation rate by Westergren method	ESR Bld Qn Westrgrn	mm/h	\N	\N	mm/h
URBC	URINE RBC	0.00508540217	13945-1	Erythrocytes [#/area] in Urine sediment by Microscopy high power field	RBC #/area UrnS HPF	/[HPF]	\N	\N	/[HPF]
GEN	GENTAMICIN	1.64367812e-05	13562-4	Gentamicin [Mass/volume] in Body fluid	Gentamicin Fld-mCnc	ug/mL	\N	\N	ug/mL
RBCMOR	RBC MORPHOLOGY	0.00484126434	6742-1	Erythrocyte morphology finding [Identifier] in Blood	RBC morph Bld	\N	\N	\N	\N
AMPC	AMPHETAMINE CONFIRMATION/RT	2.2988506e-07	16369-1	Amphetamines [Presence] in Urine by Confirmatory method	Amphetamines Ur Ql Cfm	\N	\N	\N	\N
*MPA2	MYCOPHENOLIC AC GLUCURONIDE	1.1494253e-07	23905-3	Mycophenolate [Mass/volume] in Serum or Plasma	Mycophenolate SerPl-mCnc	ug/mL	\N	\N	ug/mL
UCLIN	URINE REDUCING SUBSTANCE	1.03448281e-06	5809-9	Reducing substances [Presence] in Urine	Reducing Subs Ur Ql	\N	\N	\N	\N
UHY	HYALINE CAST	0.000254942541	5796-8	Hyaline casts [#/area] in Urine sediment by Microscopy low power field	Hyaline Casts #/area UrnS LPF	/[HPF]	\N	\N	/[HPF]
UWE	URINE WBC ESTERASE	0.00922896527	27297-1	Leukocyte esterase [Units/volume] in Urine	Leukocyte esterase Ur-aCnc	\N	\N	\N	\N
UYEA	URINE YEAST	0.000164942525	32356-8	Yeast [Presence] in Urine sediment by Light microscopy	Yeast UrnS Ql Micro	\N	\N	\N	\N
MCH	MEAN CORPUSCULAR HEMGLOB	0.0273043681	785-6	Erythrocyte mean corpuscular hemoglobin [Entitic mass] by Automated count	MCH RBC Qn Auto	pg	\N	\N	pg
ALC	ALCOHOL,ETHYL	0.000575862068	5643-2	Ethanol [Mass/volume] in Serum or Plasma	Ethanol SerPl-mCnc	mg/dL	\N	\N	mg/dL
NA	SODIUM	0.0255732182	2951-2	Sodium [Moles/volume] in Serum or Plasma	Sodium SerPl-sCnc	mmol/L	136	145	mmol/L
ALB	ALBUMIN	0.0150833335	1751-7	Albumin [Mass/volume] in Serum or Plasma	Albumin SerPl-mCnc	g/dL	3.5	5.5	g/dL
*GFRC	GLOMERULAR FILTRATION RATE	0.0105314944	33914-3	Glomerular filtration rate/1.73 sq M.predicted by Creatinine-based formula (MDRD)	GFR/BSA.pred SerPl MDRD-ArVRat	mL/min/{1.73_m2}	\N	\N	mL/min/{1.73_m2}
*FENA	FRACTIONAL SODIUM EXCRETION	2.2988506e-07	43423-3	Sodium urate [Saturation Fraction] in 24 hour Urine	Na Urate 24h SatFr Ur	\N	\N	\N	\N
*PTHICA	CALCIUM	8.0459773e-05	2000-8	Calcium [Moles/volume] in Serum or Plasma	Calcium SerPl-sCnc	mmol/L	\N	\N	mmol/L
*GTTC100	COMMENT	1.42528734e-05	8251-1	Service comment	Service Cmnt XXX-Imp	\N	\N	\N	\N
PHOS	PHOSPHORUS	0.00200298848	2777-1	Phosphate [Mass/volume] in Serum or Plasma	Phosphate SerPl-mCnc	mg/dL	2.5	4.5	mg/dL
NRBC	NUCLEATED RBC	0.000527701166	19048-8	Nucleated erythrocytes/100 leukocytes [Ratio] in Blood	nRBC/100 WBC Bld-Rto	/100{WBCs}	\N	\N	/100{WBCs}
BSTIP	BASOPHILIC STIPPLING	2.57471256e-05	703-9	Basophilic stippling [Presence] in Blood by Light microscopy	Baso Stipl Bld Ql Smear	\N	\N	\N	\N
LN	LYMPHOCYTE, ABSOLUTE	0.00395091949	731-0	Lymphocytes [#/volume] in Blood by Automated count	Lymphocytes # Bld Auto	10*3/uL	\N	\N	10*3/uL
FFC	FLUID FIBRIN CLOT	2.37931035e-05	3254-0	Fibrin.soluble [Units/volume] in Serum by Coagulation assay	Fibrin Sol Ser-aCnc	\N	\N	\N	\N
TXGRAN	TOXIC GRANULATION	3.72413779e-05	803-7	Toxic granules [Presence] in Blood by Light microscopy	Toxic Granules Bld Ql Smear	\N	\N	\N	\N
PROG	PROGESTERONE	5.71264354e-05	2839-9	Progesterone [Mass/volume] in Serum or Plasma	Progest SerPl-mCnc	ng/mL	\N	\N	ng/mL
*PHOU24	PHOSPHORUS,24 HR URINE	3.33333332e-06	21458-5	Phosphate [Mass/volume] in 24 hour Urine	Phosphate 24h Ur-mCnc	mg/dL	\N	\N	mg/dL
*CREAC	CREATININE CLEARANCE	1.02298854e-05	13451-0	Creatinine dialysis fluid clearance	Creat Cl Dial fld+SerPl-vRate	mL/min	\N	\N	mL/min
PREGQ	HCG, QUANTITATIVE, SERUM	0.000234482752	19080-1	Choriogonadotropin [Units/volume] in Serum or Plasma	HCG SerPl-aCnc	m[IU]/mL	\N	\N	m[IU]/mL
*MICALB3	MICROALBUMIN	1.26436782e-06	43606-3	Microalbumin [Mass/time] in 4 hour Urine	Microalbumin 4h Ur-mRate	ug/min	\N	\N	ug/min
UPROTX	URINE PROTEIN	2.2988506e-07	2888-6	Protein [Mass/volume] in Urine	Prot Ur-mCnc	g/dL	\N	\N	g/dL
TCA	TRICYCLIC ANTIDEPRESSANTS	0.00056942529	4073-3	Tricyclic antidepressants [Presence] in Serum or Plasma	Tricyclics SerPl Ql	\N	\N	\N	\N
CLRU	CHLORIDE,RANDOM URINE	3.79310336e-06	2078-4	Chloride [Moles/volume] in Urine	Chloride Ur-sCnc	mmol/L	\N	\N	mmol/L
MONOSCR	INFECTIOUS MONONUCLEOSIS	0.000102298851	13238-1	Epstein Barr virus Ab [Units/volume] in Serum	EBV Ab Ser-aCnc	\N	\N	\N	\N
LC	LYMPHOCYTE PERCENT	0.0248575862	736-9	Lymphocytes/100 leukocytes in Blood by Automated count	Lymphocytes NFr Bld Auto	%	\N	\N	%
LDH	LACTATE DEHYDROGENASE	0.000253678154	2532-0	Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma	LDH SerPl-cCnc	U/L	\N	\N	U/L
MG	MAGNESIUM	0.00278574717	2593-2	Magnesium [Moles/volume] in Blood	Magnesium Bld-sCnc	mmol/L	\N	\N	mmol/L
CA	CALCIUM	0.0255062077	2000-8	Calcium [Moles/volume] in Serum or Plasma	Calcium SerPl-sCnc	mmol/L	\N	\N	mmol/L
HCT	HEMATOCRIT	0.0273245983	20570-8	Hematocrit [Volume Fraction] of Blood	Hct VFr Bld	%	39	51	%
COCA	COCAINE SCREEN	0.00056942529	3397-7	Cocaine [Presence] in Urine	Cocaine Ur Ql	\N	\N	\N	\N
*GL3P	GLUCOSE,3 HOUR	1.37931038e-05	20437-0	Glucose [Mass/volume] in Serum or Plasma --3 hours post dose glucose	Glucose 3h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
CULTBORD	CULTURE B.PERTUSSIS (RT)	1.1494253e-07	549-6	Bordetella pertussis [Presence] in Unspecified specimen by Organism specific culture	B pert XXX Ql Cult	\N	\N	\N	\N
*RAT	RHEUMATOID FACTOR TITER	2.29885063e-05	11572-5	Rheumatoid factor [Units/volume] in Serum or Plasma	Rheumatoid fact SerPl-aCnc	[IU]/mL	\N	\N	[IU]/mL
RPR	RAPID PLASMA REAGIN	0.00066160917	20507-0	Reagin Ab [Presence] in Serum by RPR	RPR Ser Ql	\N	\N	\N	\N
UNIT	URINE NITRITE	0.00922931079	5802-4	Nitrite [Presence] in Urine by Test strip	Nitrite Ur Ql Strip	\N	\N	\N	\N
K	POTASSIUM	0.0256952867	2823-3	Potassium [Moles/volume] in Serum or Plasma	Potassium SerPl-sCnc	mmol/L	3.5	5	mmol/L
RDW	RED CELL DISTRIB WIDTH	0.0273036789	788-0	Erythrocyte distribution width [Ratio] by Automated count	RDW RBC Auto-Rto	%	\N	\N	%
UPH	URINE pH	0.00922953989	2756-5	pH of Urine	pH Ur	[pH]	\N	\N	[pH]
SPC	PRESENCE OF SPERM (SPUN SPEC)	9.42528732e-06	39607-7	Spermatozoa Motile [#/area] in Semen by Microscopy high power field	Sperm Motile #/area Smn HPF	/[HPF]	\N	\N	/[HPF]
*FW	FECAL WEIGHT	2.2988506e-07	30078-0	Weight of Stool	Specimen wt Stl Qn	g	\N	\N	g
URBCC	RBC CAST	2.52873565e-06	5807-3	RBC casts [#/area] in Urine sediment by Microscopy low power field	RBC Casts #/area UrnS LPF	/[HPF]	\N	\N	/[HPF]
T4	THYROXINE	0.00106103451	3026-2	Thyroxine (T4) [Mass/volume] in Serum or Plasma	T4 SerPl-mCnc	ug/dL	\N	\N	ug/dL
UNUR	UREA NITROGEN, URINE RANDOM	1.99999995e-05	3095-7	Urea nitrogen [Mass/volume] in Urine	UUN Ur-mCnc	mg/dL	\N	\N	mg/dL
UCLIN2	URINE REDUCING SUBSTANCE	1.27586209e-05	5809-9	Reducing substances [Presence] in Urine	Reducing Subs Ur Ql	\N	\N	\N	\N
AMPH	AMPHETAMINE SCREEN	0.00056942529	8149-7	Amphetamines [Presence] in Serum or Plasma by Screen method	Amphetamines SerPl Ql Scn	\N	\N	\N	\N
*PTTP	PTT-PATIENT	0.00370712648	14979-9	Activated partial thromboplastin time (aPTT) in Platelet poor plasma by Coagulation assay	aPTT PPP	s	\N	\N	s
CO2	CARBON DIOXIDE	0.0255074706	2028-9	Carbon dioxide, total [Moles/volume] in Serum or Plasma	CO2 SerPl-sCnc	mmol/L	21	30	mmol/L
BAC	BASOPHIL PERCENT	0.0248483904	706-2	Basophils/100 leukocytes in Blood by Automated count	Basophils NFr Bld Auto	%	\N	\N	%
FHIS	FLUID HISTIOCYTE	4.4827586e-05	20493-3	Histiocytes/100 cells in Body fluid by Light microscopy	Histiocytes NFr Fld Micro	%	\N	\N	%
FCOMCC	FLUID COMMENT	2.06896561e-06	8262-8	Service comment 02	Service Cmnt 02 XXX-Imp	\N	\N	\N	\N
*RUBS	RUBELLA SCREEN	3.96551732e-05	22496-4	Rubella virus Ab [Presence] in Serum	RUBV Ab Ser Ql	\N	\N	\N	\N
LIP	LIPASE	0.00170712639	3040-3	Lipase [Enzymatic activity/volume] in Serum or Plasma	Lipase SerPl-cCnc	U/L	\N	\N	U/L
HCVAB	ANTI-HCV,2ND GENERATION	0.000201954026	22327-1	Hepatitis C virus Ab [Units/volume] in Serum	HCV Ab Ser-aCnc	\N	\N	\N	\N
LH	LH SERUM/PLASMA	5.16091968e-05	10501-5	Lutropin [Units/volume] in Serum or Plasma	LH SerPl-aCnc	m[IU]/mL	\N	\N	m[IU]/mL
ARETS	A-RETICULIN IGA SCREEN	1.1494253e-07	14273-7	Reticulin IgA Ab [Presence] in Serum	Reticulin IgA Ser Ql	\N	\N	\N	\N
PSA	PSA SCREENING	0.00155390799	10508-0	Prostate specific Ag [Presence] in Tissue by Immune stain	PSA Tiss Ql ImStn	\N	\N	\N	\N
GGT	G GLUTAMYL TRANSFERASE	5.78160907e-05	2324-2	Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma	GGT SerPl-cCnc	U/L	\N	\N	U/L
USG	URINE SPECIFIC GRAVITY	0.00922965538	2965-2	Specific gravity of Urine	Sp Gr Ur	\N	\N	\N	\N
BILT	BILIRUBIN,TOTAL	0.0144283911	1975-2	Bilirubin.total [Mass/volume] in Serum or Plasma	Bilirub SerPl-mCnc	mg/dL	0.299999999999999989	1	mg/dL
UBIL	URINE BILIRUBIN	0.00922781602	1977-8	Bilirubin.total [Presence] in Urine	Bilirub Ur Ql	\N	\N	\N	\N
POIK	POIKILOCYTOSIS	0.000792988518	779-9	Poikilocytosis [Presence] in Blood by Light microscopy	Poikilocytosis Bld Ql Smear	\N	\N	\N	\N
THEO	THEOPHYLLINE	2.2413793e-05	4049-3	Theophylline [Mass/volume] in Serum or Plasma	Theophylline SerPl-mCnc	ug/mL	\N	\N	ug/mL
*TVCA	CALCIUM,24 HR. VOL.	2.34482759e-05	1993-5	Calcium renal clearance in 24 hour	Calcium Cl 24h Ur+SerPl-vRate	mL/min	\N	\N	mL/min
*TVPHO	TOTAL URINE VOLUME	3.33333332e-06	3169-0	Volume of Unspecified specimen	Specimen vol XXX	mL	\N	\N	mL
ALYMPH	ATYPICAL LYMPHOCYTES	6.41379302e-05	13046-8	Lymphocytes Variant/100 leukocytes in Blood	Variant Lymphs NFr Bld	%	\N	\N	%
*TVNA	SODIUM,24 HR. URINE VOL.	4.71264366e-06	3169-0	Volume of Unspecified specimen	Specimen vol XXX	mL	\N	\N	mL
VALPR	VALPROIC ACID (DEPAKENE)	0.000406666659	4086-5	Valproate [Mass/volume] in Serum or Plasma	Valproate SerPl-mCnc	ug/mL	50	100	ug/mL
LDLD	LDL CHOLESTEROL DIRECT	5.50574696e-05	2089-1	Cholesterol in LDL [Mass/volume] in Serum or Plasma	LDLc SerPl-mCnc	mg/dL	\N	\N	mg/dL
UAMP	AMORPHOUS PHOSPHATES	0.000166206897	40483-0	Phosphate crystals amorphous [#/area] in Urine sediment by Microscopy low power field	Amorph Phos Cry #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
PALB	PREALBUMIN	0.000230574718	14338-8	Prealbumin [Mass/volume] in Serum or Plasma	Prealb SerPl-mCnc	g/dL	\N	\N	g/dL
LAPT	LEUKOCYTE ALKALINE PHOSPH (RT)	1.14942532e-06	4659-9	Leukocyte phosphatase [Enzymatic activity/volume] in Leukocytes	LAP WBC-cCnc	\N	\N	\N	\N
UCOL	URINE COLOR	0.00922965538	5778-6	Color of Urine	Color Ur	\N	\N	\N	\N
CORWBC	CORRECTED WHITE BLOOD COUNT	3.2183907e-06	12227-5	Leukocytes [#/volume] corrected for nucleated erythrocytes in Blood	WBC nRBC cor # Bld	10*3/uL	\N	\N	10*3/uL
MAMPH	METHAMPHETAMINE SCREEN	0.000428505737	19554-5	Methamphetamine [Presence] in Urine by Screen method	Methamphet Ur Ql Scn	\N	\N	\N	\N
GLU1	GLUCOSE, 1 HOUR	4.66666679e-05	20438-8	Glucose [Mass/volume] in Serum or Plasma --1 hour post dose glucose	Glucose 1h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
UPROT	URINE PROTEIN	0.00922885071	2888-6	Protein [Mass/volume] in Urine	Prot Ur-mCnc	g/dL	\N	\N	g/dL
*PTI	PRO TIME INR	0.0075219539	5902-2	Prothrombin time (PT) in Platelet poor plasma by Coagulation assay	PT PPP	s	8.30000000000000071	10.8000000000000007	s
*RPRT	RPR TITER	7.58620672e-06	31147-2	Reagin Ab [Titer] in Serum by RPR	RPR Ser-Titr	{titer}	\N	\N	{titer}
UURO	URINE UROBILINOGEN	0.00922804605	13658-0	Urobilinogen [Presence] in Urine	Urobilinogen Ur Ql	\N	\N	\N	\N
BASO	BASOPHILS	7.08045991e-05	28543-7	Basophils/100 leukocytes in Body fluid	Basophils NFr Fld	%	\N	\N	%
HOMO	HOMOCYSTEINE	0.000110574714	2428-1	Homocysteine [Mass/volume] in Serum or Plasma	Hcys SerPl-mCnc	\N	\N	\N	\N
*TVUA	TOTAL VOLUME	1.57471259e-05	3169-0	Volume of Unspecified specimen	Specimen vol XXX	mL	\N	\N	mL
DIG	DIGOXIN	0.000202413794	10535-3	Digoxin [Mass/volume] in Serum or Plasma	Digoxin SerPl-mCnc	ng/mL	\N	\N	ng/mL
DIL	DILANTIN (PHENYTOIN)	0.000150919543	3968-5	Phenytoin [Mass/volume] in Serum or Plasma	Phenytoin SerPl-mCnc	ug/mL	10	20	ug/mL
*MCR	MICROALBUMIN/CREATININE RATIO	0.00030080459	14959-1	Microalbumin/Creatinine [Mass Ratio] in Urine	Microalbumin/Creat Ur	mg/g{creat}	\N	\N	mg/g{creat}
SP	PRESENCE OF SPERM	1.14942532e-05	39607-7	Spermatozoa Motile [#/area] in Semen by Microscopy high power field	Sperm Motile #/area Smn HPF	/[HPF]	\N	\N	/[HPF]
USGX	URINE SPECIFIC GRAVITY	2.2988506e-07	2965-2	Specific gravity of Urine	Sp Gr Ur	\N	\N	\N	\N
*GM1IGM	GM1 ANTIBODY IGM	1.1494253e-07	51703-7	Ganglioside GM1 IgM Ab [Units/volume] in Serum by Immunoassay	GM1 Gangl IgM Ser EIA-aCnc	[arb'U]/mL	\N	\N	[arb'U]/mL
FLHGB	FLUID HEMOGLOBIN	1.1494253e-07	719-5	Hemoglobin [Mass/volume] in Cerebral spinal fluid	Hgb CSF-mCnc	g/dL	\N	\N	g/dL
*APOE	APO E FOR CARDIOVASCULAR RISK	1.1494253e-07	21619-2	APOE gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal	APOE gene Mut Anal Bld/T	\N	\N	\N	\N
*NAU24	SODIUM, URINE	4.82758605e-06	2956-1	Sodium [Moles/time] in 24 hour Urine	Sodium 24h Ur-sRate	mmol/(24.h)	\N	\N	mmol/(24.h)
*TVCLU	TOTAL VOLUME	1.1494253e-07	3169-0	Volume of Unspecified specimen	Specimen vol XXX	mL	\N	\N	mL
FMC	FLUID MUCIN CLOT	2.99999992e-05	6909-6	Mucin clot [Appearance] in Synovial fluid Qualitative	Mucin Clot Snv Ql	\N	\N	\N	\N
*PREGS	QUAL HCG, SERUM	0.000143563215	2118-8	Choriogonadotropin (pregnancy test) [Presence] in Serum or Plasma	HCG Preg SerPl Ql	\N	\N	\N	\N
AAROACH	ALLERGEN,COCKROACH AMERICAN	1.1494253e-07	30170-5	American Cockroach IgE Ab [Units/volume] in Serum	Amer Roach IgE Qn	k[IU]/L	\N	\N	k[IU]/L
CHOL	CHOLESTEROL, TOTAL	0.00491482764	2093-3	Cholesterol [Mass/volume] in Serum or Plasma	Cholest SerPl-mCnc	mg/dL	\N	200	mg/dL
PHEN	PHENOBARBITAL	1.5517242e-05	3948-7	Phenobarbital [Mass/volume] in Serum or Plasma	Phenobarb SerPl-mCnc	ug/mL	15	40	ug/mL
TARG	TARGET CELLS	0.000475632172	10381-2	Target cells [Presence] in Blood by Light microscopy	Targets Bld Ql Smear	\N	\N	\N	\N
CREA	CREATININE	0.0165775865	2160-0	Creatinine [Mass/volume] in Serum or Plasma	Creat SerPl-mCnc	mg/dL	\N	1.5	mg/dL
UAUR	URIC ACID,RANDOM URINE	1.83908048e-06	3084-1	Urate [Mass/volume] in Serum or Plasma	Urate SerPl-mCnc	mg/dL	\N	\N	mg/dL
CA125	CA 125	0.000139655167	10334-1	Cancer Ag 125 [Units/volume] in Serum or Plasma	Cancer Ag125 SerPl-aCnc	[arb'U]/mL	\N	\N	[arb'U]/mL
*FFN	FETAL FIBRONECTIN	7.70114912e-06	20404-0	Fibronectin.fetal [Presence] in Vaginal fluid	Fibronectin Fetal Vag Ql	\N	\N	\N	\N
MCHC	MEAN CORPUSCULAR HGB CONC	0.0273043681	786-4	Erythrocyte mean corpuscular hemoglobin concentration [Mass/volume] by Automated count	MCHC RBC Auto-mCnc	g/dL	\N	\N	g/dL
*BORDIGMI	B.PERTUSSIS IGM IMMUNOBLOT	3.44827583e-07	29673-1	Bordetella pertussis IgM Ab [Presence] in Serum	B pert IgM Ser Ql	\N	\N	\N	\N
*GM1IGG	GM1 ANTIBODY IGG	1.1494253e-07	51729-2	Ganglioside GM1 IgG Ab [Units/volume] in Serum by Immunoassay	GM1 Gangl IgG Ser EIA-aCnc	[arb'U]/mL	\N	\N	[arb'U]/mL
BARB	BARBITURATE SCREEN	0.00056942529	19270-8	Barbiturates [Presence] in Urine by Screen method	Barbiturates Ur Ql Scn	\N	\N	\N	\N
*TESTBIOF	TESTOSTERONE BIOAVAIL FEMALE	4.59770121e-07	2990-0	Testosterone.bioavailable [Mass/volume] in Serum or Plasma	Testost Bioavail SerPl-mCnc	ng/dL	\N	\N	ng/dL
CAUR	CALCIUM,RANDOM URINE	7.35632193e-06	17862-4	Calcium [Mass/volume] in Urine	Calcium Ur-mCnc	mg/dL	\N	\N	mg/dL
PHOSRU	PHOSPHORUS, RANDOM URINE	2.06896561e-06	2778-9	Phosphate [Mass/volume] in Urine	Phosphate Ur-mCnc	mg/dL	\N	\N	mg/dL
UURT	UROTHELIAL	0.000155977017	45385-2	Hippurate crystals [#/area] in Urine sediment by Microscopy low power field	Hippurate Cry #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
RIBOP	RIBOSOMAL P PROTEIN ANTIBODY	1.1494253e-07	13636-6	Ribosomal P Ab [Units/volume] in Serum	Ribosomal P Ab Ser-aCnc	\N	\N	\N	\N
ALIMA	ALLERGEN LIMA BEAN/WHITE BEAN	2.2988506e-07	7131-6	Lima Bean IgE Ab [Units/volume] in Serum	Lima Bean IgE Qn	k[IU]/L	\N	\N	k[IU]/L
NEC	NEUTROPHIL PERCENT	0.0248577017	770-8	Neutrophils/100 leukocytes in Blood by Automated count	Neutrophils NFr Bld Auto	%	\N	\N	%
RBC	RED BLOOD COUNT	0.0273050573	789-8	Erythrocytes [#/volume] in Blood by Automated count	RBC # Bld Auto	10*6/uL	\N	\N	10*6/uL
RETAB	RETICULOCYTE COUNT ABS	0.000242183902	14196-0	Reticulocytes [#/volume] in Blood	Retics #	10*3/uL	\N	\N	10*3/uL
BLAST	BLASTS	2.45977008e-05	26446-5	Blasts/100 leukocytes in Blood	Blasts NFr Bld	%	\N	1	%
BAN	BASOPHIL, ABSOLUTE	0.00394931016	704-7	Basophils [#/volume] in Blood by Automated count	Basophils # Bld Auto	10*3/uL	\N	\N	10*3/uL
*GL1H	GLUCOSE 1 HOUR	5.51724133e-06	20438-8	Glucose [Mass/volume] in Serum or Plasma --1 hour post dose glucose	Glucose 1h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
CSFPRO	CSF PROTEIN	4.32183915e-05	2880-3	Protein [Mass/volume] in Cerebral spinal fluid	Prot CSF-mCnc	mg/dL	\N	\N	mg/dL
ARETT	A-RETICULIN IGA TITER	1.1494253e-07	17522-4	Reticulin IgA Ab [Titer] in Serum by Immunofluorescence	Reticulin IgA Titr Ser IF	{titer}	\N	\N	{titer}
BNP	NT-ProBNP (green top)	0.00270034489	30934-4	Natriuretic peptide B [Mass/volume] in Serum or Plasma	BNP SerPl-mCnc	pg/mL	\N	\N	pg/mL
UTRP	TRIPLE PHOSPHATE	2.60919533e-05	33020-9	Triple phosphate crystals [#/area] in Urine sediment by Microscopy low power field	Tri-Phos Cry #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
UWBC	URINE WBC	0.00519793108	5821-4	Leukocytes [#/area] in Urine sediment by Microscopy high power field	WBC #/area UrnS HPF	/[HPF]	\N	\N	/[HPF]
UWBCC	WBC CAST	9.88505781e-06	5820-6	WBC casts [#/area] in Urine sediment by Microscopy low power field	WBC Casts #/area UrnS LPF	/[HPF]	\N	\N	/[HPF]
APEACH	ALLERGEN,PEACH	1.1494253e-07	6205-9	Peach IgE Ab [Units/volume] in Serum	Peach IgE Qn	k[IU]/L	\N	\N	k[IU]/L
FPH	FLUID PH	1.08045979e-05	2748-2	pH of Body fluid	pH Fld	[pH]	\N	\N	[pH]
EON	EOSINOPHIL, ABSOLUTE	0.00395091949	711-2	Eosinophils [#/volume] in Blood by Automated count	Eosinophil # Bld Auto	10*3/uL	\N	\N	10*3/uL
BT	BLEEDING TIME	2.70114942e-05	11067-6	Bleeding time	Bleeding time Patient	min	\N	\N	min
*PTP	PRO TIME PATIENT	0.0075229886	5902-2	Prothrombin time (PT) in Platelet poor plasma by Coagulation assay	PT PPP	s	8.30000000000000071	10.8000000000000007	s
TEG	TEGRETOL	4.66666679e-05	3432-2	Carbamazepine [Mass/volume] in Serum or Plasma	Carbamazepine SerPl-mCnc	ug/mL	6	12	ug/mL
MALARIASM	MALARIA SMEAR	2.06896561e-06	32700-7	Microscopic observation [Identifier] in Blood by Malaria smear	Malaria Smear Bld	\N	\N	\N	\N
TSH	TSH, ULTRA SENSITIVE (3RD GEN)	0.00502931047	11580-8	Thyrotropin [Units/volume] in Serum or Plasma by Detection limit <= 0.005 mIU/L	TSH SerPl DL<=0.005 mIU/L-aCnc	m[IU]/L	\N	\N	m[IU]/L
MICRO	MICROCYTES	0.0009370115	30434-5	Microcytes [Presence] in Blood	Microcytes Bld Ql	\N	\N	\N	\N
FAMY	AMYLASE,FLUID	5.74712658e-06	1795-4	Amylase [Enzymatic activity/volume] in Body fluid	Amylase Fld-cCnc	U/L	\N	\N	U/L
GPH	GASTRIC PH	2.2988506e-07	2749-0	pH of Gastric fluid	pH Gast	[pH]	\N	\N	[pH]
PLT	PLATELET COUNT	0.0273024142	777-3	Platelets [#/volume] in Blood by Automated count	Platelet # Bld Auto	10*3/uL	\N	\N	10*3/uL
*PREGU	PREGNANCY TEST, URINE	0.00104908051	2106-3	Choriogonadotropin (pregnancy test) [Presence] in Urine	HCG Preg Ur Ql	\N	\N	\N	\N
UEPI	SQUAMOUS EPITH	0.00395149412	45390-2	Epithelial cells.squamous [#/area] in Urine sediment by Microscopy low power field	Squamous #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
HDL	HDL CHOLESTEROL	0.00485068979	2085-9	Cholesterol in HDL [Mass/volume] in Serum or Plasma	HDLc SerPl-mCnc	mg/dL	40	\N	mg/dL
HAVM	ANTI-HAV,IGM	0.000135402297	22314-9	Hepatitis A virus IgM Ab [Presence] in Serum	HAV IgM Ser Ql	\N	\N	\N	\N
UCLINX	URINE REDUCING SUBSTANCE	1.1494253e-07	5809-9	Reducing substances [Presence] in Urine	Reducing Subs Ur Ql	\N	\N	\N	\N
MPV	MEAN PLATELET VOLUME	0.0273020696	32623-1	Platelet mean volume [Entitic volume] in Blood by Automated count	PMV Bld Auto	fL	\N	\N	fL
*UAU24	URIC ACID,24HR URINE	1.57471259e-05	3087-4	Urate [Mass/time] in 24 hour Urine	Urate 24h Ur-mRate	g/(24.h)	\N	\N	g/(24.h)
*CREAU24	CREATININE,24 HR URINE	3.9999999e-05	2162-6	Creatinine [Mass/time] in 24 hour Urine	Creat 24h Ur-mRate	g/(24.h)	\N	\N	g/(24.h)
KUR	POTASSIUM,RANDOM URINE	2.5402298e-05	2828-2	Potassium [Moles/volume] in Urine	Potassium Ur-sCnc	mmol/L	\N	\N	mmol/L
PROSUL	PROTAMINE SULFATE	2.18390801e-06	33673-5	Thrombin time.factor substitution in Platelet poor plasma by Coagulation assay --immediately after addition of protamine sulfate	TT imm SO4 PPP	s	\N	\N	s
MCV	MEAN CORPUSCULAR VOLUME	0.0273048282	787-2	Erythrocyte mean corpuscular volume [Entitic volume] by Automated count	MCV RBC Auto	fL	\N	\N	fL
FMES	FLUID MESOTHELIAL	4.2988504e-05	28544-5	Mesothelial cells/100 leukocytes in Body fluid	Mesothl Cell NFr Fld	%	\N	\N	%
ANAREF	ANTI-NUCLEAR AB REFLEX	3.05747126e-05	29950-3	Nuclear IgG Ab [Presence] in Serum by Immunoassay	Nuclear IgG Ser Ql EIA	\N	\N	\N	\N
*TVKU	POTASSIUM,24 HR. VOL.	2.18390801e-06	3169-0	Volume of Unspecified specimen	Specimen vol XXX	mL	\N	\N	mL
*BFGLUARP	BODY FLUID GLUCOSE	2.2988506e-07	2344-0	Glucose [Mass/volume] in Body fluid	Glucose Fld-mCnc	mg/dL	\N	\N	mg/dL
FWST	FECAL WRIGHT STAIN	0.000119999997	681-7	Microscopic observation [Identifier] in Unspecified specimen by Wright stain	Wright Stn XXX	\N	\N	\N	\N
FGLU	BODY FLUID GLUCOSE	5.80459782e-05	2344-0	Glucose [Mass/volume] in Body fluid	Glucose Fld-mCnc	mg/dL	\N	\N	mg/dL
*GL0P	GLUCOSE,FASTING	1.41379314e-05	1558-6	Fasting glucose [Mass/volume] in Serum or Plasma	Glucose p fast SerPl-mCnc	mg/dL	\N	\N	mg/dL
UKETX	URINE KETONES	2.2988506e-07	57734-6	Ketones [Presence] in Urine by Automated test strip	Ketones Ur Ql Strip.auto	\N	\N	\N	\N
FSH	FSH SERUM/PLASMA	0.000114367816	15067-2	Follitropin [Units/volume] in Serum or Plasma	FSH SerPl-aCnc	m[IU]/mL	\N	\N	m[IU]/mL
POLY	POLYCHROMASIA	0.000465287361	10378-8	Polychromasia [Presence] in Blood by Light microscopy	Polychromasia Bld Ql Smear	\N	\N	\N	\N
GLUPP	GLUCOSE-2HR PP	3.33333332e-06	20436-2	Glucose [Mass/volume] in Serum or Plasma --2 hours post dose glucose	Glucose 2h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
FC	FLUID COLOR	0.000130804605	6824-7	Color of Body fluid	Color Fld	\N	\N	\N	\N
FOLAT	FOLATE	0.00100379309	2284-8	Folate [Mass/volume] in Serum or Plasma	Folate SerPl-mCnc	ng/mL	\N	\N	ng/mL
SGOT	ASPARTATE AMINO TRANS	0.0145359766	1920-8	Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma	AST SerPl-cCnc	U/L	0	25	U/L
MONOS	MONOCYTES	0.00419666665	26485-3	Monocytes/100 leukocytes in Blood	Monocytes NFr Bld	%	4	9	%
CEA	CARCINOEMBRYONIC ANTIGEN	0.000370344816	2039-6	Carcinoembryonic Ag [Mass/volume] in Serum or Plasma	CEA SerPl-mCnc	ng/mL	\N	\N	ng/mL
TRIG	TRIGLYCERIDES	0.00491574733	2571-8	Triglyceride [Mass/volume] in Serum or Plasma	Trigl SerPl-mCnc	mg/dL	\N	150	mg/dL
UGRC	GRANULAR CAST	0.000163218385	5793-5	Granular casts [#/area] in Urine sediment by Microscopy low power field	Gran Casts #/area UrnS LPF	/[HPF]	\N	\N	/[HPF]
UGL	URINE GLUCOSE	0.00922873523	20406-5	Deprecated Glucose [Mass/volume] in Urine by Test strip	Deprecated Glucose Fr Ur Strip	%	\N	\N	%
EC	EOSINOPHIL COUNT	2.52873565e-06	26449-9	Eosinophils [#/volume] in Blood	Eosinophil # Bld	10*3/uL	\N	\N	10*3/uL
CREAS	CREATININE,SERUM	1.17241379e-05	2160-0	Creatinine [Mass/volume] in Serum or Plasma	Creat SerPl-mCnc	mg/dL	\N	1.5	mg/dL
AKBEAN	ALLERGEN,KIDNEY BEAN	1.1494253e-07	7129-0	Red Kidney Bean IgE Ab [Units/volume] in Serum	Red Kidney Bean IgE Qn	k[IU]/L	\N	\N	k[IU]/L
CK	CREATINE KINASE	0.00147494255	2157-6	Creatine kinase [Enzymatic activity/volume] in Serum or Plasma	CK SerPl-cCnc	U/L	\N	\N	U/L
TOBRT	TOBRAMYCIN TROUGH	1.03448281e-06	4059-2	Tobramycin [Mass/volume] in Serum or Plasma --trough	Tobramycin Trough SerPl-mCnc	mg/L	\N	\N	mg/L
CRPH	CRP HIGHLY SENSITIVE	0.000628620677	30522-7	C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method	CRP SerPl HS-mCnc	mg/L	\N	\N	mg/L
RTRO	TROPONIN I (LAB USE)	2.2988506e-07	10839-9	Troponin I.cardiac [Mass/volume] in Serum or Plasma	Troponin I SerPl-mCnc	ng/mL	\N	\N	ng/mL
FRBC	FLUID RBC	0.00015137931	26455-6	Erythrocytes [#/volume] in Body fluid	RBC # Fld	10*3/uL	\N	\N	10*3/uL
*CRP2	C-REACTIVE PROTEIN (MG/DL)	9.09195369e-05	1988-5	C reactive protein [Mass/volume] in Serum or Plasma	CRP SerPl-mCnc	mg/L	\N	\N	mg/L
SPERMAB1	ANTI-SPERM ANTIBODY IGG	1.1494253e-07	47006-2	Spermatozoa IgG Ab/100 spermatozoa in Serum by Immunobead	Sperm IgG NFr Ser IBT	%	\N	\N	%
WBC	WHITE BLOOD COUNT	0.0273051728	6690-2	Leukocytes [#/volume] in Blood by Automated count	WBC # Bld Auto	10*3/uL	\N	\N	10*3/uL
PHENC	PHENCYCLIDINE SCREEN	0.00056942529	19659-2	Phencyclidine [Presence] in Urine by Screen method	PCP Ur Ql Scn	\N	\N	\N	\N
*MERCU1	HOURS OF COLLECTION	1.1494253e-07	30211-7	Collection duration of Unspecified specimen	Collect duration Time XXX	h	\N	\N	h
UAPPX	URINE APPEARANCE	1.1494253e-07	5767-9	Appearance of Urine	Appearance Ur	\N	\N	\N	\N
FRED	FECAL REDUCING SUBSTANCE	6.78160904e-06	32211-5	Reducing substances [Mass/volume] in Stool	Reducing Subs Stl-mCnc	mg/dL	\N	\N	mg/dL
DIAS	AMYLASE,URINE	1.1494253e-07	15350-2	Amylase [Enzymatic activity/time] in 2 hour Urine	Amylase 2h Ur-cRate	U/(2.h)	\N	\N	U/(2.h)
FMONO	FLUID MONOCYTES	0.000115517243	26487-9	Monocytes/100 leukocytes in Body fluid	Monocytes NFr Fld	%	\N	\N	%
DDM	D-DIMER	0.000892988523	30240-6	Deprecated Fibrin D-dimer	Deprecated D Dimer PPP-mCnc	ug/L	\N	\N	ug/L
ANAREFX	ANTI-NUCLEAR AB W/REFLEX	6.89655167e-07	29950-3	Nuclear IgG Ab [Presence] in Serum by Immunoassay	Nuclear IgG Ser Ql EIA	\N	\N	\N	\N
*MERCU2	TOTAL VOLUME	1.1494253e-07	19153-6	Volume of unspecified time Urine	Specimen vol ?Tm Ur	mL	\N	\N	mL
ASO	ANTISTREPTOLYSIN O	2.10344824e-05	5370-2	Streptolysin O Ab [Units/volume] in Serum or Plasma	ASO Ab SerPl-aCnc	[IU]/mL	\N	\N	[IU]/mL
NEN	NEUTROPHILS,ABSOLUTE	0.0202077013	751-8	Neutrophils [#/volume] in Blood by Automated count	Neutrophils # Bld Auto	10*3/uL	\N	\N	10*3/uL
SCHIS	SCHISTOCYTES	0.000193103449	800-3	Schistocytes [Presence] in Blood by Light microscopy	Schistocytes Bld Ql Smear	\N	\N	\N	\N
USULF	SULFA CRYSTALS	1.1494253e-07	40836-9	Sulfonamide crystals [#/area] in Urine sediment by Microscopy low power field	Sulfonamide cry #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
LDLC	LDL CHOLESTEROL, CALCULATED	0.0048387358	13457-7	Cholesterol in LDL [Mass/volume] in Serum or Plasma by calculation	LDLc SerPl Calc-mCnc	mg/dL	\N	130	mg/dL
OPIA	OPIATE SCREEN	0.00056942529	19295-5	Opiates [Presence] in Urine by Screen method	Opiates Ur Ql Scn	\N	\N	\N	\N
T3	TRIIODOTHYRONINE TOTAL(T3)	0.000665977015	3053-6	Triiodothyronine (T3) [Mass/volume] in Serum or Plasma	T3 SerPl-mCnc	ng/dL	\N	\N	ng/dL
FEPCT	IRON % SATURATION	0.000531494268	2502-3	Iron saturation [Mass Fraction] in Serum or Plasma	Iron Satn MFr SerPl	%	\N	\N	%
FIB	FIBRINOGEN	0.000112183909	3255-7	Fibrinogen [Mass/volume] in Platelet poor plasma by Coagulation assay	Fibrinogen PPP-mCnc	mg/dL	\N	\N	mg/dL
*MPA1	MYCOPHENOLIC ACID	1.1494253e-07	23905-3	Mycophenolate [Mass/volume] in Serum or Plasma	Mycophenolate SerPl-mCnc	ug/mL	\N	\N	ug/mL
UAMOR	AMORPH URATES	0.000200344832	40484-8	Urate crystals amorphous [#/area] in Urine sediment by Microscopy low power field	Amorph Urate Cry #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
*TVPRO	PROTEIN,24 HR. URINE VOL.	3.26436784e-05	3169-0	Volume of Unspecified specimen	Specimen vol XXX	mL	\N	\N	mL
*PROU24	PROTEIN,URINE QUANT.	3.26436784e-05	2889-4	Protein [Mass/time] in 24 hour Urine	Prot 24h Ur-mRate	g/(24.h)	\N	\N	g/(24.h)
MACRO	MACROCYTES	0.00110379315	30424-6	Macrocytes [Presence] in Blood	Macrocytes Bld Ql	\N	\N	\N	\N
UPHX	URINE pH	2.2988506e-07	2756-5	pH of Urine	pH Ur	[pH]	\N	\N	[pH]
HGB	HEMOGLOBIN	0.0273244828	718-7	Hemoglobin [Mass/volume] in Blood	Hgb Bld-mCnc	g/dL	12	16	g/dL
FE	IRON TOTAL	0.00103873562	2498-4	Iron [Mass/volume] in Serum or Plasma	Iron SerPl-mCnc	ug/dL	\N	\N	ug/dL
OCC	OCCULT BLOOD,STOOL	0.000825517229	2335-8	Hemoglobin.gastrointestinal [Presence] in Stool	Hemoccult Stl Ql	\N	\N	\N	\N
*MICALB2	MICROALBUMIN	1.37931033e-06	14956-7	Microalbumin [Mass/time] in 24 hour Urine	Microalbumin 24h Ur-mRate	mg/(24.h)	\N	\N	mg/(24.h)
UKET	URINE KETONES	0.00922965538	57734-6	Ketones [Presence] in Urine by Automated test strip	Ketones Ur Ql Strip.auto	\N	\N	\N	\N
FT4	THYROXINE, FREE	0.00108988502	3024-7	Thyroxine (T4) free [Mass/volume] in Serum or Plasma	T4 Free SerPl-mCnc	ng/dL	\N	\N	ng/dL
CA199	CA 19-9	8.8160923e-05	24108-3	Cancer Ag 19-9 [Units/volume] in Serum or Plasma	Cancer Ag19-9 SerPl-aCnc	[arb'U]/mL	\N	\N	[arb'U]/mL
BENZ	BENZODIAZEPINE SCREEN	0.00056942529	3389-4	Benzodiazepines [Presence] in Serum or Plasma	Benzodiaz SerPl Ql	\N	\N	\N	\N
CREA*	CREATININE	0.00918678194	2160-0	Creatinine [Mass/volume] in Serum or Plasma	Creat SerPl-mCnc	mg/dL	\N	1.5	mg/dL
*GL1P	GLUCOSE,1 HOUR	1.40229886e-05	20438-8	Glucose [Mass/volume] in Serum or Plasma --1 hour post dose glucose	Glucose 1h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
FERR	FERRITIN	0.000587241375	2276-4	Ferritin [Mass/volume] in Serum or Plasma	Ferritin SerPl-mCnc	ng/mL	\N	\N	ng/mL
T3U	T3 UPTAKE	0.000573678175	3050-2	Triiodothyronine resin uptake (T3RU) in Serum or Plasma	T3RU NFr SerPl	%	\N	\N	%
*GL0	GLUCOSE,FASTING	5.63218373e-06	1558-6	Fasting glucose [Mass/volume] in Serum or Plasma	Glucose p fast SerPl-mCnc	mg/dL	\N	\N	mg/dL
WNILEPCR	WEST NILE VIR RNA BY RT-PCR/FZ	4.59770121e-07	32361-8	West Nile virus RNA [Presence] in Serum by Probe and target amplification method	WNV RNA Ser Ql PCR	\N	\N	\N	\N
PSAC	PSA DIAGNOSTIC	0.000330689654	2857-1	Prostate specific Ag [Mass/volume] in Serum or Plasma	PSA SerPl-mCnc	ng/mL	0	4	ng/mL
AONION1	ALLERGEN,ONION	1.1494253e-07	6193-7	Onion IgE Ab [Units/volume] in Serum	Onion IgE Qn	k[IU]/L	\N	\N	k[IU]/L
HYPO	HYPOCHROMASIA	0.000317471277	30400-6	Hypochromia [Presence] in Blood	Hypochromia Bld Ql	\N	\N	\N	\N
ASOT	ANTISTREPTOLYSIN O TITER	3.44827595e-06	22568-0	Streptolysin O Ab [Titer] in Serum	ASO Ab Titr Ser	{titer}	\N	\N	{titer}
HBSAG	HEPATITIS B SURFACE ANTIGEN	0.000298505736	5195-3	Hepatitis B virus surface Ag [Presence] in Serum	HBV surface Ag Ser Ql	\N	\N	\N	\N
OSMOU	OSMOLALITY-URINE	0.000147356317	2695-5	Osmolality of Urine	Osmolality Ur	mosm/kg	\N	\N	mosm/kg
HBCM	ANTI-HEP B CORE,IGM	0.000131264373	31204-1	Hepatitis B virus core IgM Ab [Presence] in Serum	HBV core IgM Ser Ql	\N	\N	\N	\N
FPRO	FLUID PROTEIN	5.94252888e-05	2881-1	Protein [Mass/volume] in Body fluid	Prot Fld-mCnc	g/dL	\N	\N	g/dL
BFGLUARP	BODY FLUID GLUCOSE ARUP	1.1494253e-07	2344-0	Glucose [Mass/volume] in Body fluid	Glucose Fld-mCnc	mg/dL	\N	\N	mg/dL
LITHIUM	LITHIUM	5.89655174e-05	14334-7	Lithium [Moles/volume] in Serum or Plasma	Lithium SerPl-sCnc	mol/L	\N	\N	mol/L
*GL4	GLUCOSE,4 HOUR	3.44827583e-07	26541-3	Glucose [Mass/volume] in Serum or Plasma --4 hours post dose glucose	Glucose 4h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
FLDH	FLUID LDH	3.75862073e-05	2529-6	Lactate dehydrogenase [Enzymatic activity/volume] in Body fluid	LDH Fld-cCnc	U/L	\N	\N	U/L
UWEX	URINE WBC ESTERASE	2.2988506e-07	27297-1	Leukocyte esterase [Units/volume] in Urine	Leukocyte esterase Ur-aCnc	\N	\N	\N	\N
*TVCRE	CREATININE,24 HR. VOL.	3.88505759e-05	2164-2	Creatinine renal clearance in 24 hour	Creat Cl 24h Ur+SerPl-vRate	mL/min	\N	\N	mL/min
*CAU24	CALCIUM,URINE	2.34482759e-05	6874-2	Calcium [Mass/time] in 24 hour Urine	Calcium 24h Ur-mRate	mg/(24.h)	\N	\N	mg/(24.h)
*ORGUC	CREATININE,URINE - mg/dL	1.1494253e-07	2161-8	Creatinine [Mass/volume] in Urine	Creat Ur-mCnc	mg/dL	\N	\N	mg/dL
CORT	CORTISOL	0.000182068965	2143-6	Cortisol [Mass/volume] in Serum or Plasma	Cortis SerPl-mCnc	ug/dL	\N	\N	ug/dL
METHO	METHOTREXATE	1.1494253e-07	14836-1	Methotrexate [Moles/volume] in Serum or Plasma	MTX SerPl-sCnc	umol/L	\N	\N	umol/L
FV	FLUID VOLUME	0.000130344823	12254-9	Volume of Body fluid	Specimen vol Fld	L	\N	\N	L
TESTOS	TESTOSTERONE TOTAL	0.00014793103	2986-8	Testosterone [Mass/volume] in Serum or Plasma	Testost SerPl-mCnc	ng/dL	\N	\N	ng/dL
*GL5	GLUCOSE,5 HOUR	3.44827583e-07	26543-9	Glucose [Mass/volume] in Serum or Plasma --5 hours post dose glucose	Glucose 5h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
PEST	PLATELET ESTIMATE	0.00527126435	9317-9	Platelet adequacy [Presence] in Blood by Light microscopy	Platelet Bld Ql Smear	\N	\N	\N	\N
VANC	VANCOMYCIN	0.00046160919	20578-1	Vancomycin [Mass/volume] in Serum or Plasma	Vancomycin SerPl-mCnc	ug/mL	\N	\N	ug/mL
*GL2	GLUCOSE,2 HOUR	5.51724133e-06	20436-2	Glucose [Mass/volume] in Serum or Plasma --2 hours post dose glucose	Glucose 2h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
FCRY	FLUID CRYSTALS	3.32183918e-05	6825-4	Crystals [type] in Body fluid by Light microscopy	Crystals Fld Micro	\N	\N	\N	\N
UWAX	WAXY CAST	1.56321839e-05	5819-8	Waxy casts [#/area] in Urine sediment by Microscopy low power field	Waxy Casts #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
*PTHIN	PTH,INTACT	8.05747113e-05	2731-8	Parathyrin.intact [Mass/volume] in Serum or Plasma	PTH-Intact SerPl-mCnc	pg/mL	\N	\N	pg/mL
MOC	MONOCYTE PERCENT	0.0248575862	5905-5	Monocytes/100 leukocytes in Blood by Automated count	Monocytes NFr Bld Auto	%	\N	\N	%
IBC	IRON BINDING CAPACITY	0.000586091948	2500-7	Iron binding capacity [Mass/volume] in Serum or Plasma	TIBC SerPl-mCnc	ug/dL	\N	\N	ug/dL
SAL	SALICYLATES	0.000284023001	4024-6	Salicylates [Mass/volume] in Serum or Plasma	Salicylates SerPl-mCnc	mg/dL	\N	\N	mg/dL
URAC	URIC ACID	0.00056942529	3084-1	Urate [Mass/volume] in Serum or Plasma	Urate SerPl-mCnc	mg/dL	\N	\N	mg/dL
*CLU24	CHLORIDE,URINE 24HR	1.1494253e-07	2079-2	Chloride [Moles/time] in 24 hour Urine	Chloride 24h Ur-sRate	mmol/(24.h)	\N	\N	mmol/(24.h)
FOC	FLUID OTHER CELLS	2.98850568e-06	30468-3	Unidentified cells/100 leukocytes in Cerebral spinal fluid	Unident Cells NFr CSF	%	\N	\N	%
TYLE	ACETAMINOPHEN (TYLENOL)	0.000297931023	3298-7	Acetaminophen [Mass/volume] in Serum or Plasma	APAP SerPl-mCnc	ug/mL	\N	\N	ug/mL
*UUN24	UREA NITROGEN,24HR URINE	1.14942532e-06	12979-1	Urea nitrogen [Mass/volume] in Peritoneal dialysis fluid --24 hour specimen	Urea nit 24h sp DiafP-mCnc	mg/L	\N	\N	mg/L
VITB12	VITAMIN B12	0.000952758593	2132-9	Cobalamin (Vitamin B12) [Mass/volume] in Serum or Plasma	Vit B12 SerPl-mCnc	pg/mL	\N	\N	pg/mL
TOBRP	TOBRAMYCIN PEAK	1.03448281e-06	4057-6	Tobramycin [Mass/volume] in Serum or Plasma --peak	Tobramycin Peak SerPl-mCnc	mg/L	\N	\N	mg/L
BUN	UREA NITROGEN	0.0256419536	3094-0	Urea nitrogen [Mass/volume] in Serum or Plasma	BUN SerPl-mCnc	mg/dL	10	20	mg/dL
OVAL	OVALOCYTES	0.00101252878	774-0	Ovalocytes [Presence] in Blood by Light microscopy	Ovalocytes Bld Ql Smear	\N	\N	\N	\N
UUROX	URINE UROBILINOGEN	2.2988506e-07	13658-0	Urobilinogen [Presence] in Urine	Urobilinogen Ur Ql	\N	\N	\N	\N
UNITX	URINE NITRITE	2.2988506e-07	5802-4	Nitrite [Presence] in Urine by Test strip	Nitrite Ur Ql Strip	\N	\N	\N	\N
UOB	URINE OCCULT BLOOD	0.00922942534	5794-3	Hemoglobin [Presence] in Urine by Test strip	Hgb Ur Ql Strip	\N	\N	\N	\N
UCP	CALCIUM PHOSPHATE	2.2988506e-07	45388-6	Calcium phosphate crystals [#/area] in Urine sediment by Microscopy low power field	Ca Phos Cry #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
EOS	EOSINOPHILS	0.00182574708	32593-6	Eosinophils/100 leukocytes in Unspecified specimen	Eosinophil NFr XXX	%	\N	\N	%
TSHRFLX	TSH W/REFLEX TO FT4	9.86206869e-05	11580-8	Thyrotropin [Units/volume] in Serum or Plasma by Detection limit <= 0.005 mIU/L	TSH SerPl DL<=0.005 mIU/L-aCnc	m[IU]/L	\N	\N	m[IU]/L
FHCT	FLUID HEMATOCRIT	1.1494253e-07	11153-4	Hematocrit [Volume Fraction] of Body fluid	Hct VFr Fld	%	\N	\N	%
SWBC	SEMEN WBC	4.31034496e-05	10579-1	Leukocytes [#/volume] in Semen	WBC # Smn	10*3/uL	\N	\N	10*3/uL
BFPRO	BODY FLUID PROTEIN (ARUP)	2.2988506e-07	2881-1	Protein [Mass/volume] in Body fluid	Prot Fld-mCnc	g/dL	\N	\N	g/dL
*BBDNA	BORRELIA BURGDORFERI DNA/PCR	2.2988506e-07	4991-6	Borrelia burgdorferi DNA [Presence] in Unspecified specimen by Probe and target amplification method	B burgdor DNA XXX Ql PCR	\N	\N	\N	\N
NAUR	SODIUM,RANDOM URINE	0.000257471256	2955-3	Sodium [Moles/volume] in Urine	Sodium Ur-sCnc	mmol/L	\N	\N	mmol/L
*KU24	POTASSIUM,URINE	2.29885063e-06	2829-0	Potassium [Moles/time] in 24 hour Urine	Potassium 24h Ur-sRate	mmol/(24.h)	\N	\N	mmol/(24.h)
CHROMB1	CHROMOSOME,PERIPHERAL BLD	3.44827583e-07	29770-5	Karyotype [Identifier] in Blood or Tissue Nominal	Karyotyp Bld/T	\N	\N	\N	\N
TRO	TROPONIN I	0.00569402287	10839-9	Troponin I.cardiac [Mass/volume] in Serum or Plasma	Troponin I SerPl-mCnc	ng/mL	\N	\N	ng/mL
THC	TETRAHYDROCANNABINOID	0.00056942529	3426-4	Tetrahydrocannabinol [Presence] in Urine	THC Ur Ql	\N	\N	\N	\N
RET%	RETICULOCYTE COUNT %	0.000242873561	17849-1	Reticulocytes/100 erythrocytes in Blood by Automated count	Retics/100 RBC NFr Auto	%	\N	\N	%
UUACR	URIC ACID CRYSTAL	3.35632176e-05	40485-5	Urate crystals [#/area] in Urine sediment by Microscopy low power field	Urate Cry #/area UrnS LPF	/[LPF]	\N	\N	/[LPF]
UCOLX	URINE COLOR	2.2988506e-07	5778-6	Color of Urine	Color Ur	\N	\N	\N	\N
SEGS	POLYMORPH NEUTROPHIL	0.00431988528	20473-5	Polymorphonuclear cells [Presence] in Unspecified specimen by Wright stain	Polys XXX Ql Wright Stn	\N	\N	\N	\N
FA	FLUID APPEARANCE	0.000130574714	9335-1	Appearance of Body fluid	Appearance Fld	\N	\N	\N	\N
MON	MONOCYTES, ABSOLUTE	0.00395091949	742-7	Monocytes [#/volume] in Blood by Automated count	Monocytes # Bld Auto	10*3/uL	\N	\N	10*3/uL
TP	PROTEIN,TOTAL	0.0142959766	2885-2	Protein [Mass/volume] in Serum or Plasma	Prot SerPl-mCnc	g/dL	5.5	8	g/dL
PYRKIN	PYRUVATE KINASE	2.2988506e-07	32552-2	Pyruvate kinase [Enzymatic activity/mass] in Red Blood Cells	PK RBC-cCnt	U/g{Hb}	\N	\N	U/g{Hb}
PROL	PROLACTIN	9.52873597e-05	2842-3	Prolactin [Mass/volume] in Serum or Plasma	Prolactin SerPl-mCnc	ng/mL	\N	\N	ng/mL
METAS	METAMYELOCYTES	0.000380229874	30433-7	Metamyelocytes [#/volume] in Blood	Metamyelocytes # Bld	10*3/uL	\N	\N	10*3/uL
PROMY	PROMYELOCYTE	1.20689656e-05	26524-9	Promyelocytes/100 leukocytes in Blood	Promyelocytes NFr Bld	%	\N	5	%
FWBC	FLUID WBC	0.000132413799	26466-3	Leukocytes [#/volume] in Body fluid	WBC # Fld	10*3/uL	\N	\N	10*3/uL
*GL2P	GLUCOSE,2 HOUR	1.39080457e-05	20436-2	Glucose [Mass/volume] in Serum or Plasma --2 hours post dose glucose	Glucose 2h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
*GL3	GLUCOSE,3 HOUR	3.44827583e-07	20437-0	Glucose [Mass/volume] in Serum or Plasma --3 hours post dose glucose	Glucose 3h p Glc SerPl-mCnc	mg/dL	\N	\N	mg/dL
UBAC	BACTERIA	0.0035421839	5769-5	Bacteria [#/area] in Urine sediment by Microscopy high power field	Bacteria #/area UrnS HPF	/[HPF]	\N	\N	/[HPF]
ANISO	ANISOCYTOSIS	0.00187137933	38892-6	Anisocytosis [Presence] in Blood	Anisocytosis Bld Ql	\N	\N	\N	\N
CSFGLU	CSF GLUCOSE	4.33333335e-05	2342-4	Glucose [Mass/volume] in Cerebral spinal fluid	Glucose CSF-mCnc	mg/dL	\N	\N	mg/dL
AFP	ALPHA FETOPROTEIN	0.000109885055	1834-1	Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma	AFP SerPl-mCnc	ng/mL	\N	\N	ng/mL
ALKPHOS	ALKALINE PHOSPHATASE	0.0142822992	6768-6	Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma	ALP SerPl-cCnc	U/L	30	120	U/L
SGPT	ALANINE AMINO TRANSFERASE	0.0145275863	1742-6	Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma	ALT SerPl-cCnc	U/L	0	25	U/L
TOBR	TOBRAMYCIN RANDOM	1.72413797e-06	35670-9	Tobramycin [Mass/volume] in Serum or Plasma	Tobramycin SerPl-mCnc	mg/L	\N	\N	mg/L
\.


--
-- PostgreSQL database dump complete
--

