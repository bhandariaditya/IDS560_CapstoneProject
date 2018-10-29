DROP TABLE IF EXISTS Control_elements;

CREATE TABLE Control_elements (
    CIK VARCHAR(50),
    Period VARCHAR(50),
    Control VARCHAR(50),
    Amount FLOAT
);

DROP PROCEDURE [dbo].[control_elements_sp]
GO


CREATE PROCEDURE control_elements_sp
AS 



GO
with 
    crdt as
        (select CIK, period, sum(amount) 'crd_amt' from income_statement where debit_credit='credit' group by period, CIK),
    dbt as
        (select CIK, period, sum(amount) 'dbt_amt' from income_statement where debit_credit='debit' group by period, CIK),
    eqty as
        (select CIK, period, sum(amount) 'tot_eqty' from balance_sheet where [group] like 'Stock%' group by period, CIK)

insert into Control_elements
    (CIK, period, Control, Amount)
select x.CIK, x.PERIOD, 'Return_on_equity' Control, x.return_on_equity 
FROM
    (select 
        final.CIK, final.period, (final.net_income)/eqty.tot_eqty 'Return_on_equity' 
    from 
        (
    select crdt.CIK, crdt.PERIOD, crdt.crd_amt, dbt.dbt_amt, crdt.crd_amt-dbt.dbt_amt 'net_income' from crdt join dbt on crdt.period=dbt.period and crdt.CIK=dbt.CIK
    ) final
        join eqty on eqty.period=final.period and eqty.CIK=final.CIK) x;


--Current Ratio
BEGIN TRANSACTION Current_Ratio
INSERT INTO Control_elements  
        (CIK,Period,Control,Amount)
        select x.CIK CIK,x.[Period] Period,'Current Ratio' Control, x.amount/y.amount as Amount
        from
                    (select[CIK],[period] ,[sub_group1],sum(amount) amount from balance_sheet
                    where [sub_group1] in ('Current assets')
                    GROUP BY [period],[sub_group1],[CIK]         
                    ) x,
                    (select [CIK],[period],[sub_group1],sum(amount) amount from balance_sheet
                    where [sub_group1] in ('Current liabilities')
                    GROUP BY [period],[sub_group1],[CIK]         
                    )  y
        where  x.[Period] = y.[Period]
        and x.CIK = y.CIK 
COMMIT TRANSACTION Current_Ratio;

--Quick Ratio
BEGIN TRANSACTION Quick_Ratio
INSERT INTO Control_elements  
        (CIK,Period,Control,Amount)
select  isnull(e.CIK,f.CIK) as CIK , isnull(e.[period],f.[period]) as period,'Quick Ratio' Control, isnull(e.amount,0)/isnull(f.amount,0)as amount      
 FROM
    (select  isnull(c.CIK,d.CIK) as CIK , isnull(c.[period],d.[period]) as period, isnull(c.amount,0)+isnull(d.amount,0)as amount
        FROM     
            (select  isnull(a.CIK,b.CIK) as CIK , isnull(a.[period],b.[period]) as period, isnull(a.amount,0)+isnull(b.amount,0)as amount
                            
                    FROM         
                            (select [CIK],[period],sum(amount)amount from balance_sheet
                                                where [helement] like ('Cash%')
                                                group by [CIK],[period]
                                                ) a               
                            FULL outer join                  
                            (select[CIK],[period],sum(amount)amount from balance_sheet
                                                where [helement] like ('Mar%')
                                                group by [CIK],[period]
                                                ) b on  a.CIK = b.CIK AND a.[Period] = b.[Period] ) c
     FULL outer join
    (select[CIK],[period],sum(amount)amount from balance_sheet
                    where [helement] like ('Accounts receivable%')
                    group by [CIK],[period]) d on    d.CIK = c.CIK and   d.[Period] = c.[Period]) e      
join 
 (select [CIK],[period],sum(amount)amount from balance_sheet
         where [sub_group1] in ('Current liabilities')
         group by [CIK],[period])f on    f.CIK = e.CIK and   f.[Period] = e.[Period]
COMMIT TRANSACTION Quick_Ratio;


--Inventory Turnover
BEGIN TRANSACTION Inventory_Turnover
INSERT INTO Control_elements  
        (CIK,Period,Control, Amount)
select x.CIK,x.[period],'Inventory turnover' Control, z.amount/(x.amount+y.amount)/2 Amount from (  
        select CIK,year(cast(replace([period],'FY','') as date))-1  yearBefore,[period],sum(amount) amount
        from balance_sheet
        where [helement] like ('Inven%')
        group by [CIK],[period]) x,(  
        select CIK,year(cast(replace([period],'FY','') as date))  year,[period], sum(amount)   amount
        from balance_sheet
        where [helement] like ('Inven%')
        group by [CIK],[period])y,(
        select   [CIK],[group] ,year(cast(replace([period],'FY','') as date)) year, sum(amount) amount
        from income_statement
        where [group] = 'Cost of sales'   
        group by [CIK],[group],[period]
        )z
where x.CIK = y.CIK 
and z.CIK= x.CIK
and x.yearBefore = y.year
and z.year=y.year
COMMIT TRANSACTION Inventory_Turnover;


--Account receivables Turnover
BEGIN TRANSACTION Account_receivables_Turnover
INSERT INTO Control_elements  
        (CIK,Period,Control, Amount)
select x.CIK,x.[period],'Account receivables Turnover' Control, z.amount/(x.amount+y.amount)/2 Amount from (  
        select CIK, year(cast(replace([period],'FY','') as date))-1  yearBefore,[period],sum(amount) amount
        from balance_sheet
        where [helement] like ('Accounts receivable%')
        group by [CIK],[period]) x,(  
        select CIK,year(cast(replace([period],'FY','') as date))  year,[period], sum(amount)   amount
        from balance_sheet
        where [helement] like ('Accounts receivable%')
        group by [CIK],[period])y,(
        select   [CIK],[group] ,year(cast(replace([period],'FY','') as date)) year, sum(amount) amount
        from income_statement
        where [group] = 'Revenues'   
        group by [CIK],[group],[period]
        )z
where x.CIK = y.CIK 
and z.CIK= x.CIK
and x.yearBefore = y.year
and z.year=y.year;
COMMIT TRANSACTION Account_receivables_Turnover;

--Account payables  Turnover
BEGIN TRANSACTION Account_payables_Turnover
INSERT INTO Control_elements  
        (CIK,Period,Control, Amount)
select x.CIK,x.[period],'Accounts payable Turnover' Control, z.amount/(x.amount+y.amount)/2 Amount from (  
        select CIK, year(cast(replace([period],'FY','') as date))-1  yearBefore,[period],sum(amount) amount
        from balance_sheet
        where [helement] like ('Accounts payable%')
        group by [CIK],[period]) x,(  
        select CIK,year(cast(replace([period],'FY','') as date))  year,[period], sum(amount)   amount
        from balance_sheet
        where [helement] like ('Accounts payable%')
        group by [CIK],[period])y,(
        select   [CIK],[group] ,year(cast(replace([period],'FY','') as date)) year, sum(amount) amount
        from income_statement
        where [group] = 'Revenues'   
        group by [CIK],[group],[period]
        )z
where x.CIK = y.CIK 
and z.CIK= x.CIK
and x.yearBefore = y.year
and z.year=y.year;
COMMIT TRANSACTION Account_payables_Turnover;


--Net Income Ratio
BEGIN TRANSACTION Net_Income_Ratio
INSERT INTO Control_elements  
        (CIK,Period,Control, Amount)
select x.CIK, x.period, 'Net income ratio'Control, (x.amount-y.amount)/z.amount Amount
from
        (select CIK, period, sum(amount) amount from income_statement 
        where [debit_credit] = 'credit'
        group BY CIK,period)x,
        (select CIK,period, sum(amount) amount from income_statement 
        where [debit_credit] = 'debit'
        group BY CIK,period)y,
        (select CIK,period, sum(amount) amount from income_statement 
        where [group] like 'Revenue%'
        group BY CIK,period)z

where x.CIK     = y.CIK
and   x.period  = y.period
and   x.CIK     = z.CIK
and   x.period  = z.period;
COMMIT TRANSACTION Net_Income_Ratio;


--Technical margin (revenue - cogs)
BEGIN TRANSACTION Technical_margin
INSERT INTO Control_elements  
        (CIK,Period,Control, Amount)
select x.CIK, x.period, 'Tech Margin ratio'Control, (x.amount-y.amount)/x.amount Amount
from
        (select CIK, period, sum(amount) amount from income_statement 
        where [group] = 'Revenues'
        group BY CIK,period)x,
        (select CIK,period, sum(amount) amount from income_statement 
        where [group] = 'Cost of sales'
        group BY CIK,period)y
where x.CIK     = y.CIK
and   x.period  = y.period
COMMIT TRANSACTION Technical_margin;


--Margin before taxes
BEGIN TRANSACTION Margin_before_taxe
INSERT INTO Control_elements  
        (CIK,Period,Control, Amount)
select x.CIK, x.period, 'Margin before taxes'Control, (x.amount-y.amount)/z.amount Amount
from 
        (select [CIK],[period],[debit_credit],sum(amount) amount from income_statement
                where [group] <> 'Tax'
                and [debit_credit] = 'credit'
                group by [CIK],[period],[debit_credit])x,
        (select [CIK],[period],[debit_credit],sum(amount) amount from income_statement
                where [group] <> 'Tax'
                and [debit_credit] = 'debit'
                group by [CIK],[period],[debit_credit])y,
        (select [CIK],[period],sum(amount) amount from income_statement
                where [group] = 'Revenues'
                GROUP BY [CIK],[period])z
WHERE x.CIK     = y.CIK
and   x.period  = y.period
and   x.CIK     = z.CIK
and   x.period  = z.period;
COMMIT TRANSACTION Margin_before_taxe;


--Share of general expenses over total costs
BEGIN TRANSACTION general_expenses
INSERT INTO Control_elements   
        (CIK,Period,Control, Amount)
select x.CIK, x.period, 'Administrative expense ratio' Control, x.amount/y.amount Amount
from 
        (select [CIK],[period],sum(amount) amount from income_statement
                where [sub_group1] = 'General and administrative'
                group by [CIK],[period])x,
        (select [CIK],[period],sum(amount) amount from income_statement
                where [debit_credit] = 'debit'
                and [group] <> 'Tax'
                group by [CIK],[period])y
WHERE x.CIK     = y.CIK
and   x.period  = y.period;
COMMIT TRANSACTION general_expenses;
