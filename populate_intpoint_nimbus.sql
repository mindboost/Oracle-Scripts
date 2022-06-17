/* Created By: Marlon Devall
   Created For: BMC team integration point database
   Creation Date: November 2010
   Modify Date:	April 2014


   Update Date: April 2014		Comment: Added comments/high level exception handling
*/

SET SERVEROUTPUT ON
REM ================================ server intpoint nimbus =========================================================
REM ====== MDEVALL	Updated:09/04/2013	Added export_group_id			       ======================
REM ====== MDEVALL      Updated:11/14/2011      Removed snip: and domain!='' from where clause ======================
REM ====== MDEVALL      Updated:07/18/2012      Added and lower(a.server)=s.server_name(+) cust_prod=================

set time on
set timing on
DECLARE
v_rows number :=0;
BEGIN
      for nimbus_server in
                (SELECT distinct 'nimbus' as export_group_id, lower(server) server,
                 CASE WHEN domain is null then server
                 	WHEN domain in ('ca1-fv00190','iserver.com','jp3-lv00026','va1lq00001soho1.securesites.net') then server
                 		ELSE domain
                 	END domain,
                 1 p_function,
                 CASE WHEN segment like '%ss%' then  'SS'
                      WHEN segment like '%mssql%' then 'W'
                      WHEN segment like '%mysql%' then  'L'
                      WHEN segment like '%oracle%' then 'L'
                      WHEN segment like '%windows%' then 'W'
                      WHEN segment like '%freebsd%' then 'F'
                      WHEN segment like '%solaris%' then 'S'
                      WHEN segment like '%linux%' then 'L'
                      		ELSE 'na'
                 END os,
                 ip
           	 FROM server@intpoint_provdss
           	 WHERE (lower(server)) not in (select distinct server_name from server))

      LOOP
        	   INSERT into server (export_group_id, server_name, host_name,p_function, os) 
                   values (nimbus_server.export_group_id, nimbus_server.server, nimbus_server.domain, nimbus_server.p_function, nimbus_server.os);
		   v_rows := v_rows + 1;
      END loop;

dbms_output.put_line ('The populate server module inserted ' || v_rows || ' Nimbus records into: SERVER Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

-- COMMIT;
END POPULATE_INTPOINT_NIMBUS_DATA;
/

REM ======================================================= customer intpoint nimbus =============================================
DECLARE
v_rows number :=0;
Begin
      FOR nimbus_customer in
		(SELECT lower(c.customer) customer, 'nimbus' as the_group, trim(c.status) status, c.name, substr(contact,1,instr(contact,' ',-1)) fname, trim(substr(contact,
		 	rtrim(instr(contact,' ')))) lname, c.address1 , c.address2, c.city, c.state, c.country, c.zip, c.phone, c.fax, c.email, c.channel 
	         	,decode(decode    (c.customer,'04628712',c.customer,'53890412',c.customer,c.channel),'04628712','oem','53890412','oem','retail','retail'
        	 	,'retail2','retail','ocn','oem','viaverio','reseller','premier','reseller','rapidsite','reseller','infostr','reseller','employee','reseller'
        	 	,'shomei','oem','rsj','reseller','na') meta_channel
        	 FROM nimbus_customer@intpoint_rollup c
        	 WHERE c.customer !='verio' and status in ('A','D') and lower(c.customer) not in (select distinct customer_userid from intpoint.customer))

      LOOP
		   INSERT into customer (customer_userid, export_group_id, status, company, first_name, last_name, address1, address2, city, state, country, zip, phone, fax,
		  	  	email, id_channel, id_subchannel, reseller) 
		   	  values (nimbus_customer.customer, nimbus_customer.the_group, nimbus_customer.status
                	  	,nimbus_customer.name, nimbus_customer.fname, nimbus_customer.lname, nimbus_customer.address1, nimbus_customer.address2
                	  	,nimbus_customer.city, nimbus_customer.state, nimbus_customer.country, nimbus_customer.zip, nimbus_customer.phone, nimbus_customer.fax
                	  	,nimbus_customer.email, nimbus_customer.meta_channel, nimbus_customer.channel,'n/a');
			   v_rows := v_rows + 1;
      END loop;

dbms_output.put_line ('The populate Nimbus customer module inserted ' || v_rows || ' Nimbus records into: CUSTOMER Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

-- COMMIT;
END POPULATE_INTPOINT_NIMBUS_DATA;
/
REM ========================================================= product intpoint nimbus =============================================
DECLARE
v_rows number :=0;
Begin
      FOR nimbus_product in
		(SELECT distinct 'null' prod_version, lower(v.acct_code) acct_code, lower(v.product_type_desc) product_type_desc, 
		 	'null' prod_source
		 FROM verio_gl_ref@intpoint_rollup v
		 WHERE status_rec='A' and lower(v.acct_code) 
			not in (select prod_name from product))
      LOOP

		  INSERT into product (prod_version, prod_name, prod_description, prod_source) 
			 values (nimbus_product.prod_version, nimbus_product.acct_code, nimbus_product.product_type_desc, nimbus_product.prod_source);
			 v_rows := v_rows + 1;
      END loop;

dbms_output.put_line ('The populate Nimbus product module inserted ' || v_rows || ' Nimbus records into: PRODUCT Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);


-- COMMIT;
END POPULATE_INTPOINT_NIMBUS_DATA;
/
REM ===================================================== domain intpoint nimbus ===================================================
DECLARE
v_rows number :=0;
Begin
      for nimbus_domain in

       		(SELECT distinct (lower(cp.name)) name
	 	 FROM   nimbusdss.customer@intpoint_rollup c, nimbusdss.custprod@intpoint_rollup cp, verio_gl_ref@intpoint_rollup v
	 	 WHERE  c.customer=cp.customer 
			and cp.product=v.acct_code 
	 		and    v.product_family_desc in ('Domain Products')
	 		and    cp.product in ('SRegister','STransfer','SDomain')
	 		and    cp.name is not null
	 		and    v.status_rec='A'
	 		and    cp.status in ('N','M','I')
	 		and    c.status in ('A','D')
         		and    cp.name not in (select distinct fqdn from domain)
         	UNION
         	SELECT distinct (lower(ap.name)) name
	 	FROM   nimbusdss.customer@intpoint_rollup c, nimbusdss.acctprod@intpoint_rollup ap, verio_gl_ref@intpoint_rollup v
	 	WHERE  c.customer=ap.customer and ap.product=v.acct_code
	 		and    v.product_family_desc in ('Domain Products')
	 		and    ap.product in ('SRegister','STransfer','SDomain')
	 		and    ap.name is not null
	 		and    v.status_rec='A'
	 		and    ap.status in ('N','M','I')
	 		and    c.status in ('A','D')
         		and    ap.name not in (select distinct fqdn from domain))

       LOOP
         insert into domain (fqdn) 
                values (nimbus_domain.name);
	        v_rows := v_rows + 1;
       END loop;

dbms_output.put_line ('The populate Nimbus domain module inserted ' || v_rows || ' Autobahn records into: DOMAIN Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

-- COMMIT;
END POPULATE_INTPOINT_NIMBUS_DATA;
/
REM ============================================= cust_prod intpoint nimbus =======================================================
-- Changed this populate from cursor to regular insert into. Back up in original named populate_intpoint_nimbus_08062012.sql 
-- 08/16/2012 removed s.server_id=server_id in sub query. Comparison to null was causing duplicates.
BEGIN
      insert into cust_prod (customer_id, product_id, server_id)
		(select distinct c.customer_id, p.product_id, s.server_id
		 FROM nimbusdss.acctprod ap,product p,customer c, nimbusdss.account a,nimbusdss.acctprod_sh apsh, nimbusdss.product np, server s
		 WHERE lower(a.customer)=c.customer_userid
			and lower(a.server)=s.server_name(+)
			and a.account=ap.account
			and lower(ap.product)=p.prod_name
			and lower(np.product)=p.prod_name
			and ap.prod_version=np.prod_version
			--and ap.product like 'MServer%'
			and ap.segment not like '%mon'
			and ap.segment not like '%test%'
			and ap.recno=apsh.recno
			and apsh.status='N'
			and a.status in ('A','D')
	        	and c.export_group_id='nimbus'
        			and not exists
					(select 1 from cust_prod where c.customer_id=customer_id and p.product_id=product_id));

EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

-- COMMIT;
END POPULATE_INTPOINT_NIMBUS_DATA;
/


REM =========================================== cust_domain intpoint nimbus =======================================================
DECLARE
    v_rows number :=0;
Begin
      for nimcustdomain in 		
	 	(SELECT distinct c1.customer_id, d1.domain_id from customer c1, domain d1, nimbusdss.customer@intpoint_rollup c, nimbusdss.custprod@intpoint_rollup cp
	 	 WHERE c1.customer_userid=c.customer
	 		and c.customer=cp.customer
	 		and cp.name=d1.fqdn
	 		and cp.status in ('N','M','I')
	 		and c.status in ('A','D')
         		and c1.export_group_id='nimbus'
	 		and cp.product in ('SRegister','STransfer','SDomain') and (customer_id, domain_id) not in (select customer_id, domain_id 
         	 FROM customer_domain)
         	 UNION
         	 SELECT distinct c1.customer_id, d1.domain_id from customer c1, domain d1, nimbusdss.customer@intpoint_rollup c, nimbusdss.acctprod@intpoint_rollup ap
	 	 WHERE c1.customer_userid=c.customer
	 		and c.customer=ap.customer
	 		and ap.name=d1.fqdn
	 		and ap.status in ('N','M','I')
	 		and c.status in ('A','D')
         		and c1.export_group_id='nimbus'
	 		and ap.product in ('SRegister','STransfer','SDomain') and (customer_id, domain_id) 
				not in (select customer_id, domain_id from customer_domain))
      LOOP

	 insert into customer_domain(customer_id, domain_id) 
                values (nimcustdomain.customer_id, nimcustdomain.domain_id);
		v_rows := v_rows + 1;
       END loop;

dbms_output.put_line ('The populate Nimbus cust_domain module inserted ' || v_rows || ' Autobahn records into: CUST_DOMAIN Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

-- COMMIT;
END POPULATE_INTPOINT_NIMBUS_DATA;
/



REM ========================================= cust_prod_domain intpoint nimbus ====================================================
DECLARE
    v_rows number :=0;
BEGIN
-- This proc updates the intpoint.cust_prod_domain table to create association between cust_prod and cust_domain
      for cprod_domain in
		(SELECT distinct c1.customer_id, d1.domain_id, cp2.product_id from customer c1, domain d1, nimbusdss.customer@intpoint_rollup c, 		
	 		nimbusdss.custprod@intpoint_rollup cp, cust_prod cp2, customer_domain cd, product p
         	 WHERE c1.customer_userid=c.customer
         		and c.customer=cp.customer
         		and cp.name=d1.fqdn
         		and cp2.customer_id=c1.customer_id
         		and cp2.customer_id=cd.customer_id
         		and cd.domain_id=d1.domain_id
         		and cp2.product_id=p.product_id
         		and p.prod_name=lower(cp.product)
         		and cp.status in ('N','M','I')
         		and c.status in ('A','D')
         		and c1.export_group_id='nimbus'
         		and cp.product in ('SRegister','STransfer','SDomain','SRegister VPS','SRegisterNew')
         		and (cp2.customer_id, d1.domain_id,cp2.product_id) 
				not in (select customer_id, domain_id,product_id from cust_prod_domain)
         	 UNION
         	 SELECT distinct c1.customer_id, d1.domain_id, cp2.product_id from customer c1, domain d1, nimbusdss.customer@intpoint_rollup c, 
			nimbusdss.acctprod@intpoint_rollup ap, cust_prod cp2, customer_domain cd, product p
         	 WHERE c1.customer_userid=c.customer
         		and c.customer=ap.customer
         		and ap.name=d1.fqdn
         		and cp2.customer_id=c1.customer_id
         		and cp2.customer_id=cd.customer_id
         		and cd.domain_id=d1.domain_id
         		and cp2.product_id=p.product_id
         		and p.prod_name=lower(ap.product)
         		and ap.status in ('N','M','I')
         		and c.status in ('A','D')
         		and c1.export_group_id='nimbus'
         		and ap.product in ('SRegister','STransfer','SDomain','SRegister VPS','SRegisterNew')
         		and (cp2.customer_id, d1.domain_id,cp2.product_id) 
				not in (select customer_id, domain_id,product_id from cust_prod_domain))

      LOOP
     		INSERT INTO cust_prod_domain(customer_id, domain_id,product_id) 
			values (cprod_domain.customer_id, cprod_domain.domain_id,cprod_domain.product_id);
		        v_rows := v_rows + 1;
      END LOOP;

dbms_output.put_line ('The Nimbus cprod_domain module inserted ' || v_rows || ' Nimbus records into: CUST_PROD_DOMAIN Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

-- COMMIT;
END;
/
EXIT
