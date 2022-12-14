--Hacer un trigger que al cargar un crédito verifique que el importe del mismo sumado a los importes de los créditos que actualmente
--solicitó esa persona no supere al triple de la declaración de ganancias.
--Sólo deben tenerse en cuenta en la sumatoria los créditos que no se encuentren cancelados.
--De no poder otorgar el crédito aclararlo con un mensaje.
ALTER TRIGGER [dbo].[TR_NUEVO_CREDITO] ON [dbo].[Creditos]
INSTEAD OF INSERT
AS
BEGIN

			DECLARE @DNI VARCHAR(10) -- ASIGNARLE EL DNI (INSETED)
			DECLARE @IMPORTE MONEY  -- ASIGNARLE EL VALOR DEL PRESTAMO(INSERTED)
			DECLARE @GANANCIA MONEY  -- ASIGNARLE EL VALOR DE GANANCIAS(PERSONAS)

			--ASGINACION DE VALORES A LAS VARIABLES
			SELECT @DNI=DNI,@IMPORTE=Importe  FROM inserted
			SELECT @GANANCIA=DeclaracionGanancias FROM Personas
			WHERE DNI=@DNI

			DECLARE @TOTAL_ACTIVOS MONEY
			SELECT @TOTAL_ACTIVOS = SUM(Importe) FROM Creditos
			WHERE DNI=@DNI AND Cancelado=0



			DECLARE @TOTAL_CRED MONEY
			SET @TOTAL_CRED= @TOTAL_ACTIVOS+@IMPORTE

			DECLARE @LIMITE_MAX MONEY
			SET @LIMITE_MAX= @GANANCIA*3

			IF (@TOTAL_CRED < @LIMITE_MAX)
			 BEGIN
				INSERT INTO CREDITOS(IDBanco,DNI,Fecha,Importe,Plazo,Cancelado)
				SELECT IDBanco,DNI,Fecha,Importe,Plazo,Cancelado FROM inserted
			 END

			ELSE
			BEGIN
				PRINT('EXCEDE EL LIMITE MAXIMO OTORGADO, COMUNIQUESE CON LA ENTIDAD BANCARIA...')
			END
END

---------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TRIGGER [dbo].[TR_NUEVO_CREDITO] ON [dbo].[Creditos]
AFTER INSERT
AS
BEGIN

			DECLARE @DNI VARCHAR(10) -- ASIGNARLE EL DNI (INSETED)
			DECLARE @GANANCIA MONEY  -- ASIGNARLE EL VALOR DE GANANCIAS(PERSONAS)

			--ASGINACION DE VALORES A LAS VARIABLES
			SELECT @GANANCIA=DeclaracionGanancias FROM Personas
			WHERE DNI=@DNI

			DECLARE @TOTAL_ACTIVOS MONEY
			SELECT @TOTAL_ACTIVOS = SUM(Importe) FROM Creditos
			WHERE DNI=@DNI AND Cancelado=0


			DECLARE @LIMITE_MAX MONEY
			SET @LIMITE_MAX= @GANANCIA*3

			IF (@TOTAL_ACTIVOS > @LIMITE_MAX)
			 BEGIN
				ROLLBACK TRANSACTION
				PRINT ('EXCEDE EL LIMITE MAXIMO OTORGADO, COMUNIQUESE CON LA ENTIDAD BANCARIA...')
			 END

			ELSE
			BEGIN
				PRINT ('CREDITO  OTORGADO EXITOSAMENTE...')
			END
END
----------------------------------------------------------------------------------------------------------------------------------------
--Hacer un trigger que al eliminar un crédito realice la cancelación del mismo
ALTER TRIGGER [dbo].[TR_CANCELACION_CREDITO] ON [dbo].[Creditos]
INSTEAD OF DELETE
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
		DECLARE  @ID BIGINT
		SELECT @ID=ID FROM deleted

		UPDATE Creditos SET Cancelado=1
		WHERE ID =(@ID)
		--WHERE ID IN(@ID) OPCION QUE ABARCA MUCHOS ID

		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
	 ROLLBACK TRANSACTION 
	 PRINT ('No se pudo eliminar el registro')
	END CATCH

END
----------------------------------------------------------------------------------------------------------------------------------
--Hacer un trigger que no permita otorgar créditos con un plazo de 20 o más años a personas 
--cuya declaración de ganancias sea menor al promedio de declaración de ganancias.
ALTER TRIGGER  [dbo].[TR_VALIDACIONGANANCIA] ON [dbo].[Creditos]AFTER INSERTASBEGIN	BEGIN TRY		DECLARE @DNI VARCHAR(10)		DECLARE @GANANCIAS MONEY , @PROMEDIO_GANANCIAS MONEY		DECLARE @PLAZO SMALLINT		SELECT  @DNI=DNI ,@PLAZO=PLAZO FROM inserted		SELECT @GANANCIAS= DeclaracionGanancias FROM Personas		WHERE DNI =@DNI 		SELECT @PROMEDIO_GANANCIAS= AVG(DeclaracionGanancias)FROM Personas		IF( @PLAZO >=20 AND @GANANCIAS< @PROMEDIO_GANANCIAS)		BEGIN		 ROLLBACK TRANSACTION		 PRINT ('No se puede otorga el prestamo , ya el plazo supera lo permitido')		END	END TRY	BEGIN CATCH	END CATCHEND--------------------------------------------------------------------------------------------------------------
--Hacer un procedimiento almacenado que reciba dos fechas y liste todos los créditos otorgados entre esas fechas. 
--Debe listar el apellido y nombre del solicitante, el nombre del banco, el tipo de banco, la fecha del crédito y el importe solicitado.

ALTER PROC [dbo].[SP_CREDITOS_X_FECHA](
	@FECHA_DESDE DATE,
	@FECHA_HASTA DATE
)
AS

BEGIN
	BEGIN TRY
	IF(@FECHA_DESDE< @FECHA_HASTA)
		SELECT * FROM VW_CREDITOS
		WHERE Fecha BETWEEN @FECHA_DESDE  AND @FECHA_HASTA
	END TRY

	BEGIN CATCH
	 RAISERROR ('NO SE PUDO COMPLETAR LA CONSULTA',16,1)
	END CATCH
END
