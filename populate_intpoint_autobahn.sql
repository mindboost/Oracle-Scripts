SET SERVEROUTPUT ON

/* Created By: Marlon Devall
   Created For: BMC team integration point database
   Creation Date: November 2010
   Modify Date:	April 2014


   Update Date: April 2014		Comment: Added comments/high level exception handling
*/

REM ====================================== populate server ======================================
/* Populates autobahn base server records into inpoint db if the servers have a active status_rec
   Updated - This select statement returns active records from production db where export_group_id=group_id to eliminate dupes
*/
set time on
set timing on
DECLARE
v_rows number :=0;
BEGIN
      for server in
		
      		(SELECT distinct export_group_id, lower(server) server, trim(lower(fqdn)) fqdn, 0 as function, os 
		 FROM servers
      		 WHERE status_rec='A' and export_group_id=group_id and (lower(export_group_id),lower(server),
      		       lower(fqdn)) not in (select distinct export_group_id,server_name, host_name from server)
      		       and (server) not in
      				(select distinct server_name from server) and trim(lower(fqdn)) is not null)
      LOOP

		   INSERT into server (export_group_id,server_name, host_name, p_function, os) 
			  values (server.export_group_id, server.server, server.fqdn, server.function, server.os);
      		   	  v_rows := v_rows + 1;
      END loop;
dbms_output.put_line ('The populate server module inserted ' || v_rows || ' Autobahn records into: SERVER Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

COMMIT;
END;
/
REM =================================================== populate Product ===============================================
/* The select statement returns products and their descriptions based on finance maintained table verio_gl_ref */
DECLARE
v_rows number :=0;
BEGIN
      for product in

	        (SELECT distinct 'null' as product_version, lower(v.acct_code) acct_code, lower(v.product_type_desc) product_type_desc, 'null' 	as product_source,
	                lower(v.product_name) product_name
       		 FROM verio_gl_ref v 
		 WHERE status_rec='A' and (lower(v.acct_code)) not in 
			(select prod_name from product))
      LOOP
      

		   INSERT into product (prod_version, prod_name, prod_description, prod_source, plan_long_name) 
			  values (product.product_version, product.acct_code, product.product_type_desc, product.product_source,
				  product.product_name);
      			  v_rows := v_rows + 1;
      END loop;

dbms_output.put_line ('The populate product module inserted ' || v_rows || ' Autobahn records into: PRODUCT Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

COMMIT;
END;
/

REM =========================================== domain ============================================
/*	  First Section pulls additional domains.  Pulls domains that were add on products	*/
DECLARE
v_rows number :=0;
BEGIN
      for domain in

      		(SELECT distinct(lower(up.virtkey)) virtkey
                 FROM   user_product up, verio_gl_ref v
                 WHERE  v.export_group_id=up.export_group_id and v.acct_code=up.acct_code and v.product_family_desc in ('Domain Products')
	                and v.status_rec='A' and up.status_rec='A' and (lower(up.virtkey)) not in 
 				(select distinct fqdn from domain))
      LOOP



                   INSERT into domain (fqdn) 
                          values (domain.virtkey);
      			  v_rows := v_rows + 1;      
      END loop;

dbms_output.put_line ('The populate domain add-ons module inserted ' || v_rows || ' Autobahn records into: DOMAIN Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

COMMIT;
END;
/


/***********************************Second Section pulls base account domains************************/
/* The second section of domains pulls domains associated with base account that may not be registered with us.
	This logic was added per request of Patrick Malone and BMC team.*/
DECLARE
v_rows number :=0;
BEGIN
      for domain in
     
	        (SELECT distinct(lower(u.domain)) domain
		 FROM   userfile u
		 WHERE  u.acct_status='A'
			and not exists
				(select fqdn from domain where lower(u.domain)=fqdn))
      LOOP
      		

		   INSERT into domain (fqdn) 
			   values (domain.domain);
      			   v_rows := v_rows + 1;
      END loop;

dbms_output.put_line ('The populate base domain module inserted ' || v_rows || ' Autobahn records into: DOMAIN Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

COMMIT;
END;
/



REM ====================================================== customer =====================================
/* Merge(upsert) statement used to update records that changed and insert records that do not exist
 added logic so only current rows were updated and to_char(upd_stamp,'mm/dd/yyyy')=to_char(sysdate,'mm/dd/yyyy') */

Begin
      MERGE into customer tgt
      USING 
		(SELECT lower(u.userid) userid, lower(u.export_group_id) export_group_id, trim(u.acct_status) acct_status, lower(u.company) 				company, lower(u.fname) fname, lower(u.lname) lname, lower(u.add1) add1, lower(u.add2) add2, lower(u.city) city, 
		        lower(u.state) state, lower(u.country) country, u.zip, substr(u.phone,1,20) phone, substr(u.fax,1,20) fax, lower(u.email) 				email, lower(p.id_channel) id_channel, lower(p.id_subchannel) id_subchannel, lower(u.reseller) reseller, u.upd_stamp
		 FROM   userfile u, premier_partner_subchannels p, premier_partner_dealers@intpoint_rollup pd                                
		 WHERE  u.export_group_id=pd.export_group_id and   u.reseller=pd.dealerid and   pd.export_group_id=p.export_group_id and   				pd.ppid=p.ppid and   pd.status_rec='A' and   p.status_rec='A' and   u.acct_status = 'A' and   u.status='A')src
		 ON (src.userid=tgt.customer_userid and src.export_group_id=tgt.export_group_id)
		 WHEN MATCHED
		 THEN
		 UPDATE
		 SET	tgt.status=src.acct_status
			,tgt.company=src.company
			,tgt.first_name=src.fname
			,tgt.last_name=src.lname
			,tgt.address1=src.add1
			,tgt.address2=src.add2
			,tgt.city=src.city
			,tgt.state=src.state
			,tgt.country=src.country
			,tgt.zip=src.zip
			,tgt.phone=src.phone
			,tgt.fax=src.fax
			,tgt.email=src.email
			,tgt.id_channel=src.id_channel
			,tgt.id_subchannel=src.id_subchannel
			,tgt.reseller=src.reseller
		 WHERE src.upd_stamp>tgt.ins_dt and to_char(upd_stamp,'mm/dd/yyyy')=to_char(sysdate,'mm/dd/yyyy')
		 WHEN NOT MATCHED
		 THEN
		 INSERT
			(tgt.customer_userid
			,tgt.export_group_id
			,tgt.status
			,tgt.company
			,	tgt.first_name
			,	tgt.last_name
			,	tgt.address1
			,	tgt.address2
			,	tgt.city
			,	tgt.state
			,	tgt.country
			,	tgt.zip
			,	tgt.phone
			,	tgt.fax
			,	tgt.email
			,	tgt.id_channel
			,	tgt.id_subchannel
			,	tgt.reseller)
		 VALUES
			(src.userid
			,src.export_group_id
			,       src.acct_status
			,	src.company
			,	src.fname
			,	src.lname
			,	src.add1
			,	src.add2
			,	src.city
			,	src.state
			,	src.country
			,	src.zip
			,	src.phone
			,	src.fax
			,	src.email
			,	src.id_channel
			,	src.id_subchannel
			,	src.reseller)
		 WHERE (src.acct_status='A');
COMMIT;
dbms_output.put_line('The populate customer module completed with ' || sql%rowcount || ' rows merged' );
END;
/

REM =================================================== cust_prod ===============================================
/********* First portion of union Pulls Autobahn Base Plan second pulls add on products                **********/
/******* Per BMC group added logic to pull info for base plan(userfile plancode) and addl. products in user_product				-- Changed the not exists to a "select 1" to hold down rows returned 					   *******/

DECLARE
v_rows number :=0;
BEGIN
      for cprod in

      		(SELECT c.customer_id, p.product_id, s.server_id
         	 FROM   customer c, userfile u, product p, server s
         	 WHERE  c.customer_userid=lower(u.userid) and c.export_group_id=lower(u.export_group_id) 
			and p.prod_name=lower(u.plancode) and lower(u.wserver) = s.server_name(+)
         		and u.acct_status='A'
         		and not exists
          			(SELECT 1 
				 FROM cust_prod 
				 WHERE c.customer_id=customer_id and p.product_id=product_id and s.server_id=server_id)
           			 UNION
           				SELECT  c.customer_id, p.product_id, s.server_id
           				FROM   customer c, user_product up, product p, server s, userfile u,  verio_gl_ref v
           				WHERE  c.customer_userid(+)=up.userid and c.export_group_id(+)=up.export_group_id
           				and up.export_group_id=u.export_group_id(+) and up.userid=u.userid(+)
           				and lower(up.acct_code)=p.prod_name
           				and up.export_group_id=v.export_group_id and lower(v.acct_code)=p.prod_name
           				and lower(v.product_type_desc) = p.prod_description and u.export_group_id=v.export_group_id
           				and u.wserver=s.server_name(+)
           				and c.export_group_id in (select distinct group_id from group_ids where group_status='A')
           							  and    v.status_rec='A' 
           							  and    up.status_rec='A'
           							  and    (u.acct_status='A' or u.acct_status is null)
           							  and not exists
          								(select 1 from cust_prod where c.customer_id=customer_id and 		
									 p.product_id=product_id))
      LOOP

      			INSERT into cust_prod (customer_id, product_id, server_id) 
			values (cprod.customer_id, cprod.product_id, cprod.server_id);
      			v_rows := v_rows + 1;		      
      END loop;


dbms_output.put_line ('The populate cust_prod module inserted ' || v_rows || ' Autobahn records into: CUST_PROD Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

COMMIT;
END;
/

REM ===================================================== cust_Domain ==================================
/*  This module updates the intpoint.customer_domain table to create association between customer and domain */
DECLARE
BEGIN
      for cdomain in
		(SELECT distinct c.customer_id, d.domain_id
        	 FROM   customer c, user_product up, domain d
        	 WHERE  c.customer_userid=up.userid and c.export_group_id=up.export_group_id and up.virtkey=d.fqdn
        		and up.status_rec='A' and (c.customer_id, d.domain_id) 
			not in (select customer_id, domain_id from customer_domain)
		 UNION
		 SELECT distinct c.customer_id, d.domain_id
        	 FROM   customer c, userfile u, domain d
        	 WHERE  c.customer_userid=u.userid and c.export_group_id=u.export_group_id and u.domain=d.fqdn
        		and u.acct_status='A' and (c.customer_id, d.domain_id) 
			not in (select customer_id, domain_id from customer_domain))
      LOOP


		      INSERT into customer_domain(customer_id, domain_id) 
		      values (cdomain.customer_id, cdomain.domain_id);
      END loop;

dbms_output.put_line ('The populate customer_domain module inserted ' || v_rows || ' Autobahn records into: CUSTOMER_DOMAINS Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

COMMIT;
END;
/



REM ======================================cust_prod_domain ==================================================
/* This proc updates the intpoint.cust_prod_domain table to create association between cust_prod and cust_domain */
DECLARE
    v_rows number :=0;
BEGIN
      for cprod_domain in
		(SELECT distinct c.customer_id, p.product_id, d.domain_id
        	 FROM   customer c, user_product up, domain d, product p, cust_prod cp
        	 WHERE  c.customer_userid=up.userid and c.export_group_id=up.export_group_id and up.virtkey=d.fqdn
        		and  p.prod_name=lower(up.acct_code) and  cp.product_id=p.product_id and cp.customer_id=c.customer_id
        		and  up.status_rec='A' and p.prod_description='domain name' and (c.customer_id, d.domain_id,p.product_id) 
			not in (select customer_id, domain_id, product_id from cust_prod_domain))

      LOOP
     				INSERT INTO cust_prod_domain(customer_id, domain_id,product_id) values (cprod_domain.customer_id, 	
					    cprod_domain.domain_id,cprod_domain.product_id);
				v_rows := v_rows + 1;	
      END LOOP;


dbms_output.put_line ('The cprod_domain procedure inserted ' || v_rows || ' Autobahn records into: CUST_PROD_DOMAIN Table');
EXCEPTION
WHEN OTHERS THEN 
 dbms_output.put_line ('An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);

COMMIT;
END;
/
EXIT

