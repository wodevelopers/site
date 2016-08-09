-- Function: sft_site.function_trigger_log()

-- DROP FUNCTION sft_site.function_trigger_log();

CREATE OR REPLACE FUNCTION sft_site.function_trigger_log()
  RETURNS trigger AS
$BODY$
BEGIN
	 IF TG_OP = 'INSERT' THEN
	 
                        INSERT INTO sft_site.log (id_session, tabname, schemaname, operation, new_val) VALUES (sft_site.session_log(), TG_RELNAME, TG_TABLE_SCHEMA, TG_OP, row_to_json(NEW));
                        RETURN NEW;
                        
	ELSIF TG_OP = 'UPDATE' THEN
	
                        INSERT INTO sft_site.log (id_session, tabname, schemaname, operation, new_val, old_val) VALUES (sft_site.session_log(), TG_RELNAME, TG_TABLE_SCHEMA, TG_OP, row_to_json(NEW), row_to_json(OLD));
                        RETURN NEW;
                        
        ELSIF TG_OP = 'DELETE' THEN
 
                        INSERT INTO sft_site.log (id_session, tabname, schemaname, operation, old_val) VALUES (sft_site.session_log(), TG_RELNAME, TG_TABLE_SCHEMA, TG_OP, row_to_json(OLD));
                        RETURN OLD;
 
        END IF;
        
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION sft_site.function_trigger_log()
  OWNER TO cuca_site;


-- Function: sft_site.userapplication()

-- DROP FUNCTION sft_site.userapplication();

CREATE OR REPLACE FUNCTION sft_site.userapplication()
  RETURNS integer AS
$BODY$ 
      SELECT current_setting('sessao.usuario')::integer
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;
ALTER FUNCTION sft_site.userapplication()
  OWNER TO cuca_site;


-- View: sft_site.view_loggin

-- DROP VIEW sft_site.view_loggin;

CREATE OR REPLACE VIEW sft_site.view_loggin AS 
 SELECT lpad(b.id_cliente::text, 5, '0'::text) AS codigo,
    b.chave,
    b.cnpj,
    b.razaosocial,
    b.fantasia,
    a.id,
    a.login,
    a.senha,
    a.nome,
    a.sobrenome,
    a.imagem,
    a.email,
    a.cpf,
    a.data_nascimento,
    a.telefone,
    a.primeiro_login,
    a.id_cliente,
    a.adm_conta,
        CASE
            WHEN (( SELECT cont.valida_vigencia_modulo(1004, a.id_cliente) AS valida_vigencia_modulo)) = 1 THEN
            CASE
                WHEN a.adm_conta = 1 THEN 1
                WHEN a.adm_support = 1 THEN 1
                ELSE ( SELECT sft_site_support.valida_acesso_support(a.id::integer) AS valida_acesso_support)
            END
            ELSE 0
        END AS support,
        CASE
            WHEN a.adm_conta = 1 THEN 1
            WHEN a.adm_wallet = 1 THEN 1
            ELSE ( SELECT sft_site_wallet.valida_acesso_wallet(a.id::integer) AS valida_acesso_wallet)
        END AS wallet,
        CASE
            WHEN (( SELECT cont.valida_vigencia_modulo(1005, a.id_cliente) AS valida_vigencia_modulo)) = 1 THEN
            CASE
                WHEN a.adm_conta = 1 THEN 1
                WHEN a.adm_carneleao = 1 THEN 1
                ELSE ( SELECT sft_site_carneleao.valida_acesso_carneleao(a.id::integer) AS valida_acesso_carneleao)
            END
            ELSE 0
        END AS carneleao,
        CASE
            WHEN (( SELECT cont.valida_vigencia_modulo(1006, a.id_cliente) AS valida_vigencia_modulo)) = 1 THEN
            CASE
                WHEN a.adm_conta = 1 THEN 1
                WHEN a.adm_cloud = 1 THEN 1
                ELSE ( SELECT sft_site_cloud.valida_acesso_cloud(a.id::integer) AS valida_acesso_cloud)
            END
            ELSE 0
        END AS cloud,
        CASE
            WHEN (( SELECT cont.valida_vigencia_modulo(1010, a.id_cliente) AS valida_vigencia_modulo)) = 1 THEN
            CASE
                WHEN a.adm_conta = 1 THEN 1
                WHEN a.adm_cloud = 1 THEN 1
                ELSE 0
            END
            ELSE 0
        END AS cloud_aditional
   FROM sft_site.users a
   LEFT JOIN cont.cliente b ON a.id_cliente = b.id_cliente;

ALTER TABLE sft_site.view_loggin
  OWNER TO postgres;



-- Function: sft_site_cloud.function_trigger_xml()

-- DROP FUNCTION sft_site_cloud.function_trigger_xml();

CREATE OR REPLACE FUNCTION sft_site_cloud.function_trigger_xml()
  RETURNS trigger AS
$BODY$
DECLARE 
	vXML xml;
	vCNPJCPF varchar;
	vEmitCNPJCPF varchar;
	vDestCNPJCPF varchar;
	vCFOP integer;
	
	vNNF varchar;
	vEmitxNome varchar;
	vDestxNome varchar;
	vCHNFE varchar;
	vTotalNFE numeric;
	vDHEMI date;

	vNF boolean;
	vNFS boolean;

	vTotal integer;
	vCount integer;

	vStatus varchar;

	--PARTITION	
	vSchema varchar;
	vTabFilha varchar;
	vTabFilhaEsq varchar;
	vSql varchar;
	icodempresa integer;
	iTotal integer;		
BEGIN

	SELECT cont.retorna_qtde_modulo(1006, NEW.id_cliente::integer) INTO vTotal;
	
	SELECT COUNT(id_fiscal_document) INTO vCount FROM sft_site_cloud.fiscal_document WHERE id_cliente = NEW.id_cliente;		
	
	IF (vCount = vTotal) THEN
		RAISE EXCEPTION '0001';
	ELSE
		NEW.status := 0;
		--vXML := NEW.xml;
		vXML := replace(NEW.xml::text,'&#186;',ascii('º')::text);

		vNFS := xmlexists('//Prefeitura/text()' PASSING BY REF vXML);

		IF (vNFS = 't') THEN -- NFS-e
			-- SELECIONAR CNPJ/CPF DO CLIENTE
			SELECT translate(cnpj, '.-/', '') INTO vCNPJCPF FROM cont.cliente WHERE id_cliente = NEW.id_cliente;

			vNNF := (xpath('/NFe/ChaveNFe/NumeroNFe/text()', vXML))[1]::text;
			
			vEmitCNPJCPF := COALESCE((xpath('/NFe/CPFCNPJPrestador/CNPJ/text()', vXML))[1]::text, (xpath('/NFe/CPFCNPJPrestador/CPF/text()', vXML))[1]::text);
			vDestCNPJCPF := COALESCE((xpath('/NFe/CPFCNPJTomador/CNPJ/text()', vXML))[1]::text, (xpath('/NFe/CPFCNPJTomador/CPF/text()', vXML))[1]::text);
			vEmitxNome := (xpath('/NFe/RazaoSocialPrestador/text()', vXML))[1]::text;
			vDestxNome := (xpath('/NFe/RazaoSocialTomador/text()', vXML))[1]::text;

			vCHNFE := (xpath('/NFe/ChaveNFe/NumeroNFe/text()', vXML))[1]::text || '-' || (xpath('/NFe/ChaveNFe/SerieNFe/text()', vXML))[1]::text || '-' || (xpath('/NFe/ChaveNFe/CodigoVerificacao/text()', vXML))[1]::text;

			vTotalNFE := replace(replace((xpath('/NFe/ValorServicos/text()', vXML))[1]::text, '.', ''), ',', '.')::numeric(15, 2);
			vDHEMI := (xpath('/NFe/ChaveNFe/DataEmissaoNFe/text()', vXML))[1]::text::date;

			vStatus := (xpath('/NFe/StatusNFe/text()', vXML))[1]::text;

			IF (upper(vStatus) = 'CANCELADA') THEN				
				NEW.status := 1;
			ELSE
			     
			     NEW.status := 0;   	
			END IF;
			

			IF (vCNPJCPF = vEmitCNPJCPF) THEN -- SAÍDA
				NEW.tpnf := 0;
				NEW.type_document := 1;
				NEW.nnf := vNNF;
				NEW.cnpj_cpf := vDestCNPJCPF;
				NEW.xnome := vDestxNome;
				NEW.chnfe := vCHNFE;
				NEW.total_nfe := vTotalNFE;
				NEW.dhemi := vDHEMI;				

				--'NFS-e Saída';
			ELSIF (vCNPJCPF = vDestCNPJCPF) THEN -- ENTRADA
				NEW.tpnf := 1;
				NEW.type_document := 1;
				NEW.nnf := vNNF;
				NEW.cnpj_cpf := vEmitCNPJCPF;
				NEW.xnome := vEmitxNome;
				NEW.chnfe := vCHNFE;
				NEW.total_nfe := vTotalNFE;
				NEW.dhemi := vDHEMI;				

				--'NFS-e Entrada';
			ELSE -- NENHUM
				RAISE EXCEPTION '0003';
			END IF;

		ELSE -- NF-e
			-- SELECIONAR CNPJ/CPF DO CLIENTE
			SELECT translate(cnpj, '.-/', '') INTO vCNPJCPF FROM cont.cliente WHERE id_cliente = NEW.id_cliente;

			vCFOP := substr((xpath('/n:nfeProc/n:NFe/n:infNFe/n:det/n:prod/n:CFOP/text()', vXML, '{{n,http://www.portalfiscal.inf.br/nfe}}'))[1]::text, 1, 1)::text::integer;
			vNNF := (xpath('/n:nfeProc/n:NFe/n:infNFe/n:ide/n:nNF/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text;
			vEmitCNPJCPF := COALESCE((xpath('/n:nfeProc/n:NFe/n:infNFe/n:emit/n:CNPJ/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text, (xpath('/n:nfeProc/n:NFe/n:infNFe/n:emit/n:CPF/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text);
			vDestCNPJCPF := COALESCE((xpath('/n:nfeProc/n:NFe/n:infNFe/n:dest/n:CNPJ/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text, (xpath('/n:nfeProc/n:NFe/n:infNFe/n:dest/n:CPF/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text);
			vEmitxNome := (xpath('/n:nfeProc/n:NFe/n:infNFe/n:emit/n:xNome/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text;
			vDestxNome := (xpath('/n:nfeProc/n:NFe/n:infNFe/n:dest/n:xNome/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text;
			vCHNFE := (xpath('/n:nfeProc/n:protNFe/n:infProt/n:chNFe/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text;
			vTotalNFE := (xpath('/n:nfeProc/n:NFe/n:infNFe/n:total/n:ICMSTot/n:vNF/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text::numeric(15, 2);			
			--COALESCE(3.10 , 2.00)-Vs do xml
			vDHEMI := COALESCE(substr((xpath('/n:nfeProc/n:NFe/n:infNFe/n:ide/n:dhEmi/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text, 0, 11)::date,substr((xpath('/n:nfeProc/n:NFe/n:infNFe/n:ide/n:dEmi/text()', vXML, '{{n, http://www.portalfiscal.inf.br/nfe}}'))[1]::text, 0, 11)::date);		

			IF (vCNPJCPF = vEmitCNPJCPF) THEN -- ENTRADA(NOTAS PRÓPRIAS) OU SAÍDA	
				IF (vCFOP > 4 AND vCFOP < 8) THEN
					NEW.tpnf := 0;
					NEW.type_document := 0;
					NEW.nnf := vNNF;
					NEW.cnpj_cpf := vDestCNPJCPF;
					NEW.xnome := vDestxNome;
					NEW.chnfe := vCHNFE;
					NEW.total_nfe := vTotalNFE;
					NEW.dhemi := vDHEMI;					
					--'NF-e Saída';
					
				ELSIF (vCFOP > 0 AND vCFOP < 4) THEN
					NEW.tpnf := 1;
					NEW.type_document := 0;
					NEW.nnf := vNNF;
					NEW.cnpj_cpf := vDestCNPJCPF;
					NEW.xnome := vDestxNome;
					NEW.chnfe := vCHNFE;
					NEW.total_nfe := vTotalNFE;
					NEW.dhemi := vDHEMI;					
					--'NF-e Entrada (NOTAS PRÓPRIAS)';
					
				ELSE 
					RAISE EXCEPTION '0002';
				END IF;
			ELSIF (vCNPJCPF = vDestCNPJCPF) THEN -- ENTRADA
				IF (vCFOP > 4 AND vCFOP < 8) THEN
					NEW.tpnf := 1;
					NEW.type_document := 0;
					NEW.nnf := vNNF;
					NEW.cnpj_cpf := vEmitCNPJCPF;
					NEW.xnome := vEmitxNome;
					NEW.chnfe := vCHNFE;
					NEW.total_nfe := vTotalNFE;
					NEW.dhemi := vDHEMI;					

					--'NF-e Entrada';
				ELSE 
					RAISE EXCEPTION '0002';
				END IF;	
			ELSE
				RAISE EXCEPTION '0003';
			END IF;

		END IF;
		

	END IF;


	--PARTITION	
	vSchema := 'sft_site_cloud';
	icodempresa := NEW.id_cliente;
	vTabFilha := 'fiscal_document'||'_'||to_char(NEW.id_cliente,'FM099999MI');
	vTabFilhaEsq := vSchema||'.'|| vTabFilha;
	  
	SELECT COUNT(tablename) INTO iTotal FROM pg_tables WHERE tablename = vTabFilha ;
	IF iTotal = 0 THEN 
		vSql := 'CREATE TABLE ' || vTabFilhaEsq || '() INHERITS(sft_site_cloud.fiscal_document)';
		EXECUTE vSql;
		vSql := 'ALTER TABLE ' || vTabFilhaEsq || ' ADD CHECK (id_cliente = ' || '''' || icodempresa || '''' || ')';
		EXECUTE vSql;
		vSql := 'CREATE INDEX IDX_id_empresa_' || vTabFilha || ' on ' || vTabFilhaEsq || ' (id_cliente)';		
		EXECUTE vSql;
		vSql := 'ALTER TABLE ' || vTabFilhaEsq || ' ADD CONSTRAINT pk_'|| vTabFilha || ' PRIMARY KEY(id_fiscal_document)';
		EXECUTE vSql;
		vSql := 'ALTER TABLE ' || vTabFilhaEsq || ' ADD CONSTRAINT fk_'|| vTabFilha || ' FOREIGN KEY(id_cliente) REFERENCES cont.cliente (id_cliente) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE ' ;
		EXECUTE vSql;
		vSql := 'ALTER TABLE ' || vTabFilhaEsq || ' ADD CONSTRAINT uk_chnfe_'|| vTabFilha || ' UNIQUE(chnfe) ' ;
		EXECUTE vSql;
		vSql := 'CREATE TRIGGER trigger_log_table AFTER INSERT OR UPDATE OR DELETE ON ' || vTabFilhaEsq || ' FOR EACH ROW EXECUTE PROCEDURE sft_site.function_trigger_log()';
		EXECUTE vSql;
		vSql := 'ALTER TABLE ' || vTabFilhaEsq || ' OWNER TO cuca_site; ' ;
		EXECUTE vSql;
	END IF;



        vSql := ' INSERT INTO ' || vTabFilhaEsq || '( xml, nnf, cnpj_cpf, xnome, chnfe, total_nfe, dhemi, tpnf, type_document, status, id_cliente) 
		VALUES ( ' || '''' || NEW.xml || '''' || ', ' || 
			'''' || NEW.nnf || '''' || ', ' ||
			'''' || NEW.cnpj_cpf || '''' || ', ' ||
			'''' || NEW.xnome || '''' || ', ' ||
			'''' || NEW.chnfe || '''' || ', ' ||
			NEW.total_nfe ||  ', ' ||
			'''' || NEW.dhemi || '''' || ', ' ||			
			NEW.tpnf ||  ', ' ||
			NEW.type_document ||  ', ' ||
			NEW.status ||  ', ' ||
			NEW.id_cliente ||  ')'; 
                        
        EXECUTE vSql;

	--RETURN NEW;
	RETURN NULL;
        
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION sft_site_cloud.function_trigger_xml()
  OWNER TO cuca_site;


CREATE TRIGGER trigger_log_table
  AFTER INSERT OR UPDATE OR DELETE
  ON sft_site_support.config
  FOR EACH ROW
  EXECUTE PROCEDURE sft_site.function_trigger_log();
