USE ExamenIntegrador20222C

-- Parcial: Integrador SQL LaboratorioIII
-- Alumno:  Matias Nicolas Falduti
-- Legajo:  24495

select * from Concursos
SELECT * FROM FOTOGRAFIAS
SELECT* FROM Participantes
SELECT * FROM VOTACIONES
-- 1)Hacer un procedimiento almacenado llamado SP_Ranking que a partir de un IDParticipante 
--se pueda obtener las tres mejores fotografías publicadas (si las hay).
--Indicando el nombre del concurso, apellido y nombres del participante, 
--el título de la publicación, la fecha de publicación y el puntaje promedio obtenido por esa publicación.
CREATE PROC SP_RANKING (
@IDPARTICIPANTE BIGINT
)
AS
BEGIN
SELECT TOP 3 C.Titulo,P.Apellidos,P.Nombres,F.Titulo,F.Publicacion,
(
	SELECT AVG(V.Puntaje) FROM Votaciones AS V
	WHERE F.ID= V.IDFotografia
) AS PROMEDIO
FROM  Concursos AS C
INNER JOIN Fotografias AS F ON F.IDConcurso= C.ID
INNER JOIN Participantes AS P ON P.ID= F.IDParticipante
WHERE P.ID=@IDPARTICIPANTE
ORDER BY PROMEDIO DESC
END

EXEC SP_RANKING 2
--------------------------------------------------------------------------------------------------------------------
--2Hacer un procedimiento almacenado llamado SP_Descalificar que reciba un ID de fotografía 
--y realice la descalificación de la misma. También debe eliminar todas las votaciones registradas 
--a la fotografía en cuestión. Sólo se puede descalificar una fotografía si pertenece a un concurso no finalizado.


CREATE PROC SP_DESCALIFICAR (
@IDFOTOGRAFIA BIGINT
)
AS 
BEGIN
	DECLARE @FIN DATE,@CONCURSO BIGINT,@PUBLICACION DATE
	SELECT @CONCURSO = IDConcurso,@PUBLICACION=Publicacion FROM Fotografias AS F
	WHERE F.ID=@IDFOTOGRAFIA
	SELECT @FIN =Fin FROM Concursos AS C
	WHERE C.Fin =@CONCURSO

	IF(@PUBLICACION<@FIN)
	BEGIN
		UPDATE Fotografias SET Descalificada=1 WHERE @IDFOTOGRAFIA=ID

		DELETE FROM  Votaciones 
		WHERE @IDFOTOGRAFIA= IDFotografia
	END

	ELSE
	BEGIN
		PRINT('')
	END

END




---------------------------------------------------------------------------------------------------------------------
--3Al insertar una fotografía verificar que el usuario creador de la fotografía tenga el
--ranking suficiente para participar en el concurso. También se debe verificar que el concurso haya iniciado y 
--no finalizado. Además, el participante no debe registrar una descalificación en los últimos 100 días. 
--Si ocurriese un error, mostrarlo con un mensaje aclaratorio. De lo contrario, 
--insertar el registro teniendo en cuenta que la fecha de publicación es la fecha y hora del sistema.
CREATE TRIGGER TR_FOTOGRAFIA ON FOTOGRAFIAS
AFTER INSERT
AS
BEGIN
	DECLARE @IDFOTO BIGINT
	DECLARE @IDPARTICPARTE BIGINT
	DECLARE @IDCONCURSO BIGINT 
	DECLARE @RANKING DECIMAL(5,2)
	DECLARE @RANKING_MIN DECIMAL(5,2)
	DECLARE @FEC_INI DATE
	DECLARE @FEC_FIN DATE
	DECLARE @ULTIMA_FECHA DATE

	SELECT @IDPARTICPARTE= IDParticipante, @IDCONCURSO=IDConcurso FROM inserted
		

	SELECT @RANKING= AVG (Puntaje) FROM Votaciones AS V
	INNER JOIN Fotografias AS F ON F.ID= V.IDFotografia
	INNER JOIN Participantes AS P ON P.ID= F.IDParticipante
	WHERE P.ID=IDParticipante

	SELECT @RANKING_MIN= RankingMinimo , @FEC_INI=Inicio, @FEC_FIN= FIN FROM Concursos AS C
	WHERE C.ID=@IDCONCURSO

	SELECT  @ULTIMA_FECHA = MAX (C.Fin) FROM Fotografias AS F
	INNER JOIN Concursos AS C ON C.ID= F.IDConcurso
	WHERE @IDPARTICPARTE= F.IDParticipante

	IF(@RANKING < @RANKING_MIN OR @FEC_INI>GETDATE()OR  @FEC_FIN < GETDATE()  OR DATEDIFF(DAY,@ULTIMA_FECHA,GETDATE())<100  )
	BEGIN
		ROLLBACK TRANSACTION
		PRINT ('NO SE PUDO INGRESAR  LA FOTO')
	END



END



CREATE VIEW VW_DESCALIFICADOS  AS
SELECT F.IDParticipante, C.Fin  FROM Fotografias AS F
INNER JOIN Concursos AS C ON C.ID= F.IDConcurso
WHERE F.Descalificada = 1

-----------------------------------------------------------------------------------------------------------------
--4)Al insertar una votación, verificar que el usuario que vota no lo haga más de una vez para el mismo concurso ni se 
--pueda votar a sí mismo. Tampoco puede votar una fotografía descalificada.

CREATE TRIGGER TR_VALIDACIONES ON VOTACIONES
INSTEAD OF INSERT
AS 
BEGIN 

		
		DECLARE @IDPARTICIPANTE BIGINT 
		DECLARE @IDFOTOGRAFIA BIGINT
		DECLARE @IDVOTANTE BIGINT
		DECLARE @DESCALIFICADA BIT
		DECLARE @CANT_VOTACIONES INT
		DECLARE @IDCONCURSO BIGINT

		SELECT @IDFOTOGRAFIA=IDFotografia,@IDVOTANTE=IDVotante FROM Inserted

		SELECT  @IDPARTICIPANTE=FOT.IDParticipante,@DESCALIFICADA=FOT.Descalificada,@IDCONCURSO=FOT.IDConcurso FROM FOTOGRAFIAS AS FOT

		SELECT @CANT_VOTACIONES= COUNT (*) FROM Votaciones V 
		INNER JOIN FOTOGRAFIAS AS F ON F.ID= V.IDFotografia
		WHERE V.IDVotante=@IDVOTANTE AND  F.IDConcurso=@IDCONCURSO

		IF (@CANT_VOTACIONES<2 AND @IDVOTANTE<>@IDPARTICIPANTE AND @DESCALIFICADA=0)
		BEGIN
			INSERT INTO VOTACIONES (IDVotante, IDFotografia, Fecha, Puntaje )
			SELECT IDVotante, IDFotografia, Fecha, Puntaje FROM Inserted			
		END 

		ELSE
		BEGIN
		RAISERROR ('NO SE PUDO COMPLETAR LA VOTACION',16,1)
		END
END






-------------------------------------------------------------------------------------------

--5)Hacer un listado en el que se obtenga: ID de participante, apellidos y nombres de los participantes que hayan 
--registrado al menos dos fotografías descalificadas.
SELECT FINAL.ID,FINAL.Apellidos,FINAL.Nombres FROM (
SELECT P.ID,P.Apellidos,P.Nombres ,
(
 SELECT COUNT (*) FROM Fotografias AS F
 WHERE F.IDParticipante = P.ID AND F.Descalificada=1
 ) AS'TOTAL_DESCALIFICADAS'
FROM Participantes AS P
)AS FINAL
WHERE TOTAL_DESCALIFICADAS>=2