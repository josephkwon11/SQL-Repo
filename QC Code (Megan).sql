--NIS QC Code (sending Circle K as an example again): creates pricing insights temp table that contains most updated NIS data, then checks for duplication (QC #1), checks that the final data we will load into NIS has relatively high coverage compared to the raw AP data (i.e. any lost data is due to outliers/low volume/etc. and not the result of a larger issue causing a lot of data to be kicked out) (QC #2), checks that all back data is identical (QC #3), and checks that most recent period of data is in trend with the previous five periods of data (QC #4)

USE [CircleK_Dev_PnP]
GO

/****** Object:  StoredProcedure [dbo].[CircleK_NIS_QC_Code]    Script Date: 5/12/2020 1:44:56 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

;


--IF YOUR CLIENT TRANSFERS TO DAYWINDAYP001, REMEMBER TO CREATE TEMP TABLE PRIOR TO UPDATING Pricing_Change_Recommendedations_TEMPLATE

--exec [CircleK_NIS_QC_Code]

ALTER procedure [dbo].[CircleK_NIS_QC_Code] as

---------------------------
   --CREATE TEMP TABLE--
---------------------------

--drop table [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp] --only need to drop again if you didn't drop it last time
select * into [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp] from [dbo].[Pricing_Insights_TEMPLATE];

-------------------------------------
  --QC CHECK 1: DUPLICATION CHECK--
-------------------------------------

select count(*) as 'Duplication Check 1 - Distinct Combinations' from (select distinct [Market_Name],[Time_Period],[UPC],[Condition] from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp])a
select count(*) as 'Duplication Check 2 - All Rows' from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp];
------------------------------------
   --QC CHECK 2: COVERAGE CHECK--
------------------------------------
select

cov.[Market Name],cov.[Time Period],
case
	when [Item Count % Difference] < -0.15 then 'FAIL'
	else 'PASS'
end as 'ITEM COUNT FLAG',
case
	when [Client Units % Difference] < -0.25 then 'FAIL'
	else 'PASS'
end as 'Client UNITS FLAG',
case
	when [ROM Units % Difference] < -0.25 then 'FAIL'
	else 'PASS'
end as 'ROM UNITS FLAG',
case
	when [Client Dollars % Difference] < -0.25 then 'FAIL'
	else 'PASS'
end as 'Client DOLLARS FLAG',
case
	when [ROM Dollars % Difference] < -0.25 then 'FAIL'
	else 'PASS'
end as 'ROM DOLLARS FLAG',
--IF YOUR Client USES PPGs, ITEM COUNT FLAG WILL LIKELY FAIL AND THAT IS OKAY!!
cov.[AP UPC Count],cov.[AP Client Units],cov.[AP ROM Units],cov.[AP Client Dollars],
cov.[AP ROM Dollars],cov.[NIS UPC Count],cov.[NIS Client Units],cov.[NIS ROM Units],
cov.[NIS Client Dollars],cov.[NIS ROM Dollars],cov.[Item Count % Difference],cov.[Client Units % Difference],
cov.[ROM Units % Difference],cov.[Client Dollars % Difference],cov.[ROM Dollars % Difference]

from

(select

ap.*,
nis.*,
--nis.[NIS UPC Count]-ap.[AP UPC Count] as 'Item_Count_Difference', --if Client uses PPGs, there will likely be a large item count difference and that is okay
--nis.[NIS Client Units]-ap.[AP Client Units] as 'Client_Unit_Difference',
--nis.[NIS ROM Units]-ap.[AP ROM Units] as 'ROM_Unit_Difference',
--nis.[NIS Client Dollars]-ap.[AP Client Dollars] as 'Client_Dollar_Difference',
--nis.[NIS ROM Dollars]-ap.[AP Client Dollars] as 'ROM_Dollar_Difference',
round(cast(((nis.[NIS UPC Count]-ap.[AP UPC Count])/ap.[AP UPC Count]) as float),4) as 'Item Count % Difference', --if Client uses PPGs, there will likely be a large item count % diff and that is okay
round(cast(((nis.[NIS Client Units]-ap.[AP Client Units])/ap.[AP Client Units]) as float),4) as 'Client Units % Difference',
round(cast(((nis.[NIS ROM Units]-ap.[AP ROM Units])/ap.[AP ROM Units]) as float),4) as 'ROM Units % Difference',
round(cast(((nis.[NIS Client Dollars]-ap.[AP Client Dollars])/ap.[AP Client Dollars]) as float),4) as 'Client Dollars % Difference',
round(cast(((nis.[NIS ROM Dollars]-ap.[AP ROM Dollars])/ap.[AP ROM Dollars]) as float),4) as 'ROM Dollars % Difference'


from

(select

[Market Name],
cast(RIGHT([Time Period],10) as date) as 'Time Period',
count([UPC]) as 'AP UPC Count',
sum([Units (Proj)]) as 'AP Client Units',
sum([Units (Proj) - Comp Mkt]) as 'AP ROM Units',
sum([Value (Proj)]) as 'AP Client Dollars',
sum([Value (Proj) - Comp Mkt]) as 'AP ROM Dollars'

from [CircleK_Dev_PnP].[dbo].[AP_Pricing_Data]
where [Units (Proj)]>10 and [Units (Proj) - Comp Mkt]>0
group by [Market Name],[Time Period])ap
join
(select

[Market_Name],
cast(LEFT([Time_Period],10) as date) as 'Time_Period',
cast(count([UPC]) as float) as 'NIS UPC Count',
sum([Units]) as 'NIS Client Units',
sum([Market_Units]) as 'NIS ROM Units',
sum([Dollars]) as 'NIS Client Dollars',
sum([Market_Dollars]) as 'NIS ROM Dollars'

from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp]
where [Units]>10 and [Market_Units]>0
group by [Market_Name],[Time_Period])nis
on ap.[Market Name]=nis.[Market_Name] and ap.[Time Period]=nis.[Time_Period]
where (ap.[Market Name] = 'Circle K Total TA Conv' or ap.[Market Name] = 'CIRCLE K TOTAL CENSUS'))cov

order by cov.[Time Period] asc

;

------------------------------------------------------------------------------------
 --QC CHECK 3: COMPARE DATA CURRENTLY IN NIS TO UPDATED PRICING INSIGHTS TEMPLATE--
------------------------------------------------------------------------------------
--ensures that historical data has not changed

select 
q3.[Time_Period] as 'Time Period',q3.[Condition],
case 
	when q3.[Prior Item Count] = q3.[Current Item Count] then 'PASS'
	when q3.[Item Count % Difference] between -0.03 and 0.03 then 'INVESTIGATE'
	else 'FAIL' end as 'Item Count Flag',
case 
	when round(q3.[Prior Index],4)=round(q3.[Current Index],4) then 'PASS'
	when q3.[Index % Difference] between -0.03 and 0.03  then 'INVESTIGATE'
	else 'FAIL' end as 'Index Flag',
case 
	when q3.[Prior Focus Dollars]=q3.[Current Focus Dollars] then 'PASS' 
	when q3.[Focus Dollar % Difference] between -0.03 and 0.03 then 'INVESTIGATE'
	else 'FAIL' end as 'Focus Dollars Flag',
case 
	when q3.[Prior Focus Units]=q3.[Current Focus Units] then 'PASS' 
	when q3.[Focus Unit % Difference] between -0.03 and 0.03  then 'INVESTIGATE'
	else 'FAIL' end as 'Focus Units Flag',
case 
	when q3.[Prior ROM Dollars]=q3.[Current ROM Dollars] then 'PASS' 
	when q3.[ROM Dollar % Difference] between -0.03 and 0.03  then 'INVESTIGATE'
	else 'FAIL' end as 'ROM Dollars Flag',
case 
	when q3.[Prior ROM Units]=q3.[Current ROM Units] then 'PASS' 
	when q3.[ROM Unit % Difference] between -0.03 and 0.03  then 'INVESTIGATE'
	else 'FAIL' end as 'ROM Units Flag',
case 
	when q3.[Prior Markets]=q3.[Current Markets] then 'PASS' 
	when q3.[Market % Difference] between -0.03 and 0.03  then 'INVESTIGATE'
	else 'FAIL' end as 'Markets Flag',
q3.[Item Count % Difference],q3.[Index % Difference],q3.[Focus Dollar % Difference],
q3.[Focus Unit % Difference],q3.[ROM Dollar % Difference],q3.[ROM Unit % Difference],
q3.[Market % Difference],q3.[Prior Index],q3.[Prior Item Count],q3.[Prior Focus Dollars],
q3.[Prior Focus Units],q3.[Prior ROM Dollars],q3.[Prior ROM Units],q3.[Prior Markets],
q3.[Current Index],q3.[Current Item Count],q3.[Current Focus Dollars],q3.[Current Focus Units],
q3.[Current ROM Dollars],q3.[Current ROM Units],q3.[Current Markets]

from

(select

old.*,new.[Current Index],new.[Current Item Count],new.[Current Focus Dollars],new.[Current Focus Units],
new.[Current ROM Dollars],new.[Current ROM Units],new.[Current Markets],
--new.[Current Item Count]-old.[Prior Item Count] as 'Item_Count_Difference',
--round(new.[Current Index],4)-round(old.[Prior Index],4) as 'Index_Difference',
--new.[Current Focus Dollars]-old.[Prior Focus Dollars] as 'Focus_Dollar_Difference',
--new.[Current Focus Units]-old.[Prior Focus Units] as 'Focus_Unit_Difference',
--new.[Current ROM Dollars]-old.[Prior ROM Dollars] as 'ROM_Dollar_Difference',
--new.[Current ROM Units]-old.[Prior ROM Units] as 'ROM_Unit_Difference',
--new.[Current Markets]-old.[Prior Markets] as 'Market_Difference'
round(cast(((new.[Current Item Count]-old.[Prior Item Count])/old.[Prior Item Count]) as float),4) as 'Item Count % Difference',
round(cast(((round(new.[Current Index],4)-round(old.[Prior Index],4))/round(old.[Prior Index],4)) as float),4) as 'Index % Difference',
round(cast(((new.[Current Focus Dollars]-old.[Prior Focus Dollars])/old.[Prior Focus Dollars]) as float),4) as 'Focus Dollar % Difference',
round(cast(((new.[Current Focus Units]-old.[Prior Focus Units])/old.[Prior Focus Units]) as float),4) as 'Focus Unit % Difference',
round(cast(((new.[Current ROM Dollars]-old.[Prior ROM Dollars])/old.[Prior ROM Dollars]) as float),4) as 'ROM Dollar % Difference',
round(cast(((new.[Current ROM Units]-old.[Prior ROM Units])/old.[Prior ROM Units]) as float),4) as 'ROM Unit % Difference',
round(cast(((new.[Current Markets]-old.[Prior Markets])/old.[Prior Markets]) as float),4) as 'Market % Difference'

from

(select distinct 
[Time_Period],
[Condition],
cast(sum(((100*([Dollars]/[50%_Price_Weighted_Volume]))*[Units]))/sum([Units]) as float) as 'Prior Index',
cast(count(distinct([UPC])) as float) as'Prior Item Count',
cast(sum([Dollars]) as float) as 'Prior Focus Dollars',
cast(sum([Units]) as float) as 'Prior Focus Units', 
cast(sum([Market_Dollars]) as float) as 'Prior ROM Dollars',
cast(sum([Market_Units]) as float) as 'Prior ROM Units',
cast(count(distinct([Market_Name])) as float) as 'Prior Markets'

from [CircleK].[dbo].[Pricing_Insights_TEMPLATE_TBL]
group by [Time_Period],[Condition])old
join
(select distinct 
[Time_Period],
[Condition],
cast(sum(((100*([Dollars]/[50%_Price_Weighted_Volume]))*[Units]))/sum([Units]) as float) as 'Current Index',
cast(count(distinct([UPC])) as float) as'Current Item Count',
cast(sum([Dollars]) as float) as 'Current Focus Dollars',
cast(sum([Units]) as float) as 'Current Focus Units',
cast(sum([Market_Dollars]) as float) as 'Current ROM Dollars',
cast(sum([Market_Units]) as float) as 'Current ROM Units',
cast(count(distinct([Market_Name])) as float) as 'Current Markets'

from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp]
group by [Time_Period],[Condition])new
on old.[Time_Period]=new.[Time_Period] and old.[Condition]=new.[Condition])q3
order by [Time_Period],[Condition]
;
-------------------------------------------------------
  --QC CHECK 4: Markets, Conditions, Items, Volumes--
-------------------------------------------------------

select temp.* into [CircleK_Dev_PnP].[dbo].[NIS_QC_Count_TBL_temp] from
(select 

q1.[Time_Period],q1.[Count of Markets],q1.[Count of Retail Conditions], q1.[Total Row Count],
q1.[Distinct Item Count - Total Store],q2.[Distinct Item Count - KVI],q1.[Client Dollars],
q1.[Client Units],q1.[Market Dollars],q1.[Market Units]

from 

(select distinct

[Time_Period],
count(distinct([Market_Name])) as 'Count of Markets',
count(distinct([Condition])) as 'Count of Retail Conditions',
count(*) as 'Total Row Count',
count(distinct([UPC])) as 'Distinct Item Count - Total Store',
sum([Dollars]) as 'Client Dollars',
sum([Units]) as 'Client Units',
sum([Market_Dollars]) as 'Market Dollars',
sum([Market_Units]) as 'Market Units'

from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp]
group by [Time_Period])q1
left join
(select [Time_Period], count(distinct([UPC])) as 'Distinct Item Count - KVI'
from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp] 
where [KVI Quad] = 'KVI'
group by [Time_Period])q2 
on q1.[Time_Period] = q2.[Time_Period])temp
order by [Time_Period] 

--------------------------------
        --Index Check--
--------------------------------
/*CREATE TABLE [CircleK_Dev_PnP].[dbo].[NIS_QC_Index_TBL]( --start comment out here
[Time_Period] varchar(75),
[Condition] varchar(75),
[Total Store Index] float,
[Dollars] float,
[Units] float, 
[Market Dollars] float,
[Market Units] float, 
[KVI Store Index] float,
[KVI Dollars] float,
[KVI Units] float,
[Market KVI Dollars] float,
[Market KVI Units] float,
[Count of Markets] float,
[Count of Retail Conditions] float,
[Distinct Item Count - Total Store] float,
[Distinct Item Count - KVI] float)*/ --end comment out here
delete from [CircleK_Dev_PnP].[dbo].[NIS_QC_Index_TBL] 
insert into [CircleK_Dev_PnP].[dbo].[NIS_QC_Index_TBL]
select cm.*,d.[Count of Markets],
d.[Count of Retail Conditions],d.[Distinct Item Count - Total Store],d.[Distinct Item Count - KVI]

from

(select c.*,b.[KVI Store Index],b.[KVI Dollars],b.[KVI Units],b.[Market KVI Dollars],b.[Market KVI Units] from 

(select 
[Time_Period], [Condition],sum(((100*([Dollars]/[50%_Price_Weighted_Volume]))*[Units]))/sum([Units]) as 'Total Store Index', sum([dollars]) as 'Dollars', sum([units]) as 'Units',
sum([Market_Dollars]) as 'Market Dollars',sum([Market_Units]) as 'Market Units'

from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp] where [50%_Outlier] <> 'Outlier'
group by [Time_Period], [Condition])c

left join
(select
[Time_Period], [Condition],sum(((100*([Dollars]/[50%_Price_Weighted_Volume]))*[Units]))/sum([Units]) as 'KVI Store Index',sum([dollars]) as 'KVI Dollars',sum([units]) as 'KVI Units',
sum([Market_Dollars]) as 'Market KVI Dollars',sum([Market_Units]) as 'Market KVI Units'


from [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp] where [KVI Quad] = 'KVI' and [50%_Outlier] <> 'Outlier'
group by [Time_Period],[Condition])b
on c.[Time_Period] =b.[Time_Period] and c.[Condition] = b.[Condition]) cm
left join [CircleK_Dev_PnP].[dbo].[NIS_QC_Count_TBL_temp]d on cm.[Time_Period] = d.[Time_Period]


select * from [CircleK_Dev_PnP].[dbo].[NIS_QC_Index_TBL]
order by [Time_Period]
------------------------
  --drop temp table--
------------------------
drop table [CircleK_Dev_PnP].[dbo].[NIS_QC_Count_TBL_temp]
drop table [CircleK_Dev_PnP].[dbo].[Pricing_Insights_TEMPLATE_tbl_Temp]
GO


