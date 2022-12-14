--Hacer un trigger que al registrar una captura se verifique que la cantidad de capturas que haya 
--realizado el competidor no supere las reglamentadas por el torneo. Tampoco debe permitirse registrar
--más capturas si el competidor ya ha devuelto veinte peces o más en el torneo. Indicar cada situación 
--con un mensaje de error aclaratorio. Caso contrario, registrar la captur

CREATE TRIGGER [dbo].[TR_REGISTRAR_CAPTURA] ON [dbo].[Capturas]
INSTEAD OF INSERT
AS 
BEGIN

		DECLARE @IDCOMPETIDOR BIGINT -- variable para guardar id del competidor
		DECLARE @TOTAL_CAPTURAS INT  -- viarible para calcular  el total de captura validas del competidor 
		DECLARE @TOTAL_DEVUELTOS INT -- viarible para calcular  el total de captura no validas del competidor 
		DECLARE @IDTORNEO BIGINT -- Variable para captura el id del torneo


		SELECT @IDCOMPETIDOR= IDCOMPETIDOR,@IDTORNEO=IDTorneo  FROM inserted -- CAPTURO ID COMPETIDOR

		SELECT @TOTAL_CAPTURAS= COUNT (*) FROM Capturas -- CALCULO LA CANTIDAD DE CAPTURAS 
		WHERE IDCompetidor=@IDCOMPETIDOR AND Devuelta=0

		SELECT @TOTAL_DEVUELTOS= COUNT (*) FROM Capturas --CALCULO LA CANTIDAD DE CAPTURAS DEVUELTAS
		WHERE IDCompetidor=@IDCOMPETIDOR AND Devuelta=1

		DECLARE @CAPTURAS_MAX INT 
		SELECT @CAPTURAS_MAX=T.CapturasPorCompetidor FROM Torneos AS T --BUSCO EL MAXIMO DE CAPTURAS QUE PERMITE EL TORNEO

		IF(@TOTAL_CAPTURAS<@CAPTURAS_MAX AND @TOTAL_DEVUELTOS < 20  )
		BEGIN 
		  INSERT INTO Capturas(IDCompetidor,IDTorneo,IDEspecie,FechaHora,Peso,Devuelta)
		  SELECT IDCompetidor,IDTorneo,IDEspecie,FechaHora,Peso,Devuelta  FROM inserted
		END

		ELSE 
		BEGIN
			IF(@TOTAL_CAPTURAS>=@CAPTURAS_MAX)
			BEGIN
				PRINT ('YA REALIZO EL MAXIMO DE CAPTURAS QUE PERMITE EL TORNEO')
			END
				
			IF(@TOTAL_DEVUELTOS>=20)
			BEGIN
				PRINT ('DEVOLVIO VIENTE  O  MAS PECES, NO PUEDE SEGUIR PARTICIPANDO')
			END
	 END
END



--Hacer un trigger que no permita que al cargar un torneo se otorguen más de un millón de pesos 
--en premios entre todos los torneos de ese mismo año. En caso de ocurrir indicar el error con un
--mensaje aclaratorio. Caso contrario, registrar el torneo.
CREATE TRIGGER [dbo].[TR_VALIDAR_PREMIO] ON [dbo].[Torneos]
INSTEAD OF INSERT
AS
BEGIN
	DECLARE @PREMIO MONEY -- VARIABLE PARA GUARDAR EL PREMIO
	DECLARE @ACUMULADO_X_AÑO MONEY -- VARIABLE QUE VA A GUARDAR LA SUMA DE LOS PREMIOS
	
	SELECT @PREMIO=Premio FROM inserted -- seteo el importe del premio del torneo que se va a cargar
	SELECT @ACUMULADO_X_AÑO = SUM (PREMIO) FROM Torneos
	WHERE Año = YEAR(GETDATE())

	IF(@ACUMULADO_X_AÑO + @PREMIO >1000000) 
	BEGIN
		PRINT('El premio excede el limite anual') -- mensaje de error
	END

	ELSE
	BEGIN
		INSERT INTO Torneos(Nombre,Año,Ciudad,Inicio,Fin,Premio,CapturasPorCompetidor) -- inserto el torneo 
		SELECT Nombre,Año,Ciudad,Inicio,Fin,Premio,CapturasPorCompetidor  FROM inserted
	END

END


--Hacer un trigger que al eliminar una captura sea marcada como devuelta y que al eliminar 
--una captura que ya se encuentra como devuelta se realice la baja física del registro.
ALTER TRIGGER TR_VALIDAR_ELIMINACION ON CAPTURAS
INSTEAD OF DELETE
AS
BEGIN
	DECLARE @IDCOMPETIDOR BIGINT
	DECLARE @DEVUELTA BIT

	SELECT @IDCOMPETIDOR=IDCompetidor, @DEVUELTA=Devuelta FROM deleted

	IF(@DEVUELTA=1)
	BEGIN
	 DELETE FROM Capturas 
	 WHERE IDCompetidor=@IDCOMPETIDOR
	END

	ELSE 
	BEGIN
		UPDATE Capturas SET Devuelta=1
	END

END


--Hacer un procedimiento almacenado que a partir de un IDTorneo indique los datos del ganador del mismo.
--El ganador es aquel pescador que haya sumado la mayor cantidad de puntos en el torneo.
--Se suman 3 puntos por cada pez capturado y se resta un punto por cada pez devuelto. Indicar Nombre, Apellido y Puntos.
ALTER PROCEDURE SP_PUNTO4 (
@IDTORNEO BIGINT
)
AS
BEGIN
select TOP 1 WITH TIES  Apellido,Nombre, (Capturas*3-Devueltas) as Puntos from(
select  Com.Apellido,Com.Nombre , ------------------------------------------------------
(                                                                                       
select   COUNT (*)    from Capturas as cap	
where  CAP.Devuelta=0 AND CAP.IDTorneo= @IDTORNEO AND Com.ID=cap.IDCompetidor
) as   'Capturas',
(
select   COUNT (*)    from Capturas as cap	
where  CAP.Devuelta=1 AND CAP.IDTorneo= @IDTORNEO and Com.ID=cap.IDCompetidor
) as  'Devueltas'
from Competidores as Com -----------------------------------------------------------------
) as tablafinal
ORDER BY Puntos DESC 
END