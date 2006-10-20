﻿START TRANSACTION ISOLATION LEVEL SERIALIZABLE, READ WRITE;

CREATE SCHEMA SampleModel;

CREATE DOMAIN SampleModel.OptnlUnqStrng AS CHARACTER(11) CONSTRAINT OptnlUnqStrng_Chk CHECK ((CHARACTER_LENGTH(TRIM(BOTH FROM VALUE))) >= 11) ;

CREATE DOMAIN SampleModel."Integer" AS BIGINT CONSTRAINT Integer_Chk CHECK (VALUE BETWEEN 1 AND 7) ;

CREATE DOMAIN SampleModel.DeathCause_Type AS CHARACTER VARYING(14) CONSTRAINT DthCs_Typ_Chk CHECK (VALUE IN ('natural', 'not so natural')) ;

CREATE DOMAIN SampleModel.Gender_Code AS CHARACTER(1) CONSTRAINT Gender_Code_Chk CHECK ((CHARACTER_LENGTH(TRIM(BOTH FROM VALUE))) >= 1 AND 
VALUE IN ('M', 'F')) ;

CREATE DOMAIN SampleModel.MndtryUnqStrng AS CHARACTER(11) CONSTRAINT MndtryUnqStrng_Chk CHECK ((CHARACTER_LENGTH(TRIM(BOTH FROM VALUE))) >= 11) ;

CREATE TABLE SampleModel.PersonDrivesCar
(
	DrivesCar_vin BIGINT NOT NULL, 
	DrvnByPrsn_Prsn_d BIGINT NOT NULL, 
	INSERT_DATE DATE NOT NULL, 
	UPDATE_DATE DATE , 
	ERROR_FLAG_IND FLOAT , 
	SOURCE_SYSTEM_CD CHARACTER VARYING(10) NOT NULL, 
	STUDY_SHORT_NAME CHARACTER VARYING(20) , 
	CONSTRAINT IUC18 PRIMARY KEY(DrivesCar_vin, DrvnByPrsn_Prsn_d)
);

CREATE TABLE SampleModel.PBCFPOD
(
	CarSold_vin BIGINT NOT NULL, 
	SaleDate_YMD BIGINT NOT NULL, 
	Buyer_Person_id BIGINT NOT NULL, 
	Seller_Person_id BIGINT NOT NULL, 
	INSERT_DATE DATE NOT NULL, 
	UPDATE_DATE DATE , 
	ERROR_FLAG_IND FLOAT , 
	SOURCE_SYSTEM_CD CHARACTER VARYING(10) NOT NULL, 
	STUDY_SHORT_NAME CHARACTER VARYING(20) , 
	CONSTRAINT IUC23 PRIMARY KEY(Buyer_Person_id, CarSold_vin, Seller_Person_id), 
	CONSTRAINT IUC24 UNIQUE(SaleDate_YMD, Seller_Person_id, CarSold_vin), 
	CONSTRAINT IUC25 UNIQUE(CarSold_vin, SaleDate_YMD, Buyer_Person_id)
);

CREATE TABLE SampleModel.Review
(
	Car_vin BIGINT NOT NULL, 
	Rating_Nr_Integer SampleModel."Integer" NOT NULL, 
	Criterion_Name CHARACTER VARYING(64) NOT NULL, 
	INSERT_DATE DATE NOT NULL, 
	UPDATE_DATE DATE , 
	ERROR_FLAG_IND FLOAT , 
	SOURCE_SYSTEM_CD CHARACTER VARYING(10) NOT NULL, 
	STUDY_SHORT_NAME CHARACTER VARYING(20) , 
	CONSTRAINT IUC26 PRIMARY KEY(Car_vin, Criterion_Name)
);

CREATE TABLE SampleModel.PersonHasNickName
(
	NickName CHARACTER VARYING(64) NOT NULL, 
	Person_Person_id BIGINT NOT NULL, 
	INSERT_DATE DATE NOT NULL, 
	UPDATE_DATE DATE , 
	ERROR_FLAG_IND FLOAT , 
	SOURCE_SYSTEM_CD CHARACTER VARYING(10) NOT NULL, 
	STUDY_SHORT_NAME CHARACTER VARYING(20) , 
	CONSTRAINT IUC33 PRIMARY KEY(NickName, Person_Person_id)
);

CREATE TABLE SampleModel.Person
(
	FirstName CHARACTER VARYING(64) NOT NULL, 
	Person_id BIGSERIAL NOT NULL, 
	Date_YMD BIGINT NOT NULL, 
	LastName CHARACTER VARYING(64) NOT NULL, 
	OptnlUnqStrng SampleModel.OptnlUnqStrng , 
	HatType_ColorARGB BIGINT , 
	HTHTSHTSD CHARACTER VARYING(256) , 
	OwnsCar_vin BIGINT , 
	Gender_Gender_Code SampleModel.Gender_Code NOT NULL, 
	"10" BOOLEAN NOT NULL, 
	OptnlUnqDcml DECIMAL(9) , 
	MndtryUnqDcml DECIMAL(9) NOT NULL, 
	MndtryUnqStrng SampleModel.MndtryUnqStrng NOT NULL, 
	Husband_Person_id BIGINT , 
	VT1DSEWVT1V BIGINT , 
	CPBOBON BIGINT , 
	Father_Person_id BIGINT NOT NULL, 
	Mother_Person_id BIGINT NOT NULL, 
	Death_Date_YMD BIGINT , 
	DDCDCT SampleModel.DeathCause_Type , 
	Dth_NtrlDth_20 BOOLEAN , 
	Dth_UnntrlDth_9 BOOLEAN , 
	Dth_UnntrlDth_8 BOOLEAN , 
	INSERT_DATE DATE NOT NULL, 
	UPDATE_DATE DATE , 
	ERROR_FLAG_IND FLOAT , 
	SOURCE_SYSTEM_CD CHARACTER VARYING(10) NOT NULL, 
	STUDY_SHORT_NAME CHARACTER VARYING(20) , 
	CONSTRAINT IUC2 PRIMARY KEY(Person_id), 
	CONSTRAINT IUC9 UNIQUE(OptnlUnqStrng), 
	CONSTRAINT IUC22 UNIQUE(OwnsCar_vin), 
	CONSTRAINT IUC65 UNIQUE(OptnlUnqDcml), 
	CONSTRAINT IUC69 UNIQUE(MndtryUnqDcml), 
	CONSTRAINT IUC67 UNIQUE(MndtryUnqStrng), 
	CONSTRAINT CPIUC49 UNIQUE(Father_Person_id, CPBOBON, Mother_Person_id), 
	CONSTRAINT EUC1 UNIQUE(FirstName, Date_YMD), 
	CONSTRAINT EUC2 UNIQUE(LastName, Date_YMD)
);

CREATE TABLE SampleModel.Task
(
	Task_id BIGSERIAL NOT NULL, 
	Person_Person_id BIGINT , 
	INSERT_DATE DATE NOT NULL, 
	UPDATE_DATE DATE , 
	ERROR_FLAG_IND FLOAT , 
	SOURCE_SYSTEM_CD CHARACTER VARYING(10) NOT NULL, 
	STUDY_SHORT_NAME CHARACTER VARYING(20) , 
	CONSTRAINT IUC16 PRIMARY KEY(Task_id)
);

CREATE TABLE SampleModel.ValueType1
(
	ValueType1Value BIGINT NOT NULL, 
	DSWPP BIGINT , 
	INSERT_DATE DATE NOT NULL, 
	UPDATE_DATE DATE , 
	ERROR_FLAG_IND FLOAT , 
	SOURCE_SYSTEM_CD CHARACTER VARYING(10) NOT NULL, 
	STUDY_SHORT_NAME CHARACTER VARYING(20) , 
	CONSTRAINT VlTyp1Vl_Unq PRIMARY KEY(ValueType1Value)
);

ALTER TABLE SampleModel.PersonDrivesCar ADD CONSTRAINT DrivenByPerson_FK FOREIGN KEY (DrvnByPrsn_Prsn_d)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.PBCFPOD ADD CONSTRAINT Buyer_FK FOREIGN KEY (Buyer_Person_id)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.PBCFPOD ADD CONSTRAINT Seller_FK FOREIGN KEY (Seller_Person_id)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.PersonHasNickName ADD CONSTRAINT Person_FK FOREIGN KEY (Person_Person_id)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.Person ADD CONSTRAINT Husband_FK FOREIGN KEY (Husband_Person_id)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.Person ADD CONSTRAINT VT1DSEWFK FOREIGN KEY (VT1DSEWVT1V)  REFERENCES SampleModel.ValueType1 (ValueType1Value)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.Person ADD CONSTRAINT Father_FK FOREIGN KEY (Father_Person_id)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.Person ADD CONSTRAINT Mother_FK FOREIGN KEY (Mother_Person_id)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.Task ADD CONSTRAINT Person_FK FOREIGN KEY (Person_Person_id)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE SampleModel.ValueType1 ADD CONSTRAINT DsSmthngWthPrsn_FK FOREIGN KEY (DSWPP)  REFERENCES SampleModel.Person (Person_id)  ON DELETE RESTRICT ON UPDATE RESTRICT;

COMMIT WORK;

