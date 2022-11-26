--1) Se pide agregar una modificación a la base de datos para que permita registrar la
--calificación (de 1 a 10) que el Cliente le otorga al Chofer en un viaje y además una
--observación opcional. Lo mismo debe poder registrar el Chofer del Cliente.
--Importante:
--- No se puede modificar la estructura de la tabla de Viajes.
--- Sólo se puede realizar una calificación por viaje del Cliente al Chofer.
--- Sólo se puede realizar una calificación por viaje del Chofer al Cliente.
--- Puede haber viajes que no registren calificación por parte del Chofer o del
--Cliente.

CREATE TABLE [dbo].[PuntosChofer] (
    [ID]               BIGINT  PRIMARY KEY  IDENTITY (1, 1) NOT NULL,
    [IDViaje]          BIGINT    REFERENCES VIAJES (ID)  NULL, 
    [Fecha]            DATETIME NOT NULL,
    [PuntosObtenidos]  INT   CHECK (PuntosObtenidos BETWEEN 0 AND  10 ) NOT NULL,
    [Observacion]      varchar(200)  NULL,
    [FechaVencimiento] DATE     NOT NULL
)

CREATE TABLE [dbo].[PuntosClientes] (
    [ID]               BIGINT  PRIMARY KEY  IDENTITY (1, 1) NOT NULL,
    [IDViaje]          BIGINT    REFERENCES VIAJES (ID)  NULL, 
    [Fecha]            DATETIME NOT NULL,
    [PuntosObtenidos]  INT   CHECK (PuntosObtenidos BETWEEN 0 AND  10 ) NOT NULL,
    [Observacion]      varchar(200)  NULL,
    [FechaVencimiento] DATE     NOT NULL
)




--2) Realizar una vista llamada VW_ClientesDeudores que permita listar: Apellidos,
--Nombres, Contacto (indica el email de contacto, si no lo tiene el teléfono y de lo
--contrario "Sin datos de contacto"), cantidad de viajes totales, cantidad de viajes no
--abonados y total adeudado. Sólo listar aquellos clientes cuya cantidad de viajes no
--abonados sea superior a la mitad de viajes totales realizados.ALTER VIEW VW_CLIENTESDEUDORES ASSELECT  FINAL.Apellidos,FINAL.Nombres,FINAL.CONTACTO,FINAL.TOTAL_VIAJES,FINAL.TOTAL_NOPAGOS,FINAL.TOTAL_ADEUDADO FROM (SELECT CL.Apellidos,CL.Nombres ,COALESCE(CL.EMAIL,CL.TELEFONO,'SIN DATOS DE CONTACTO') AS CONTACTO,(	SELECT COUNT(*) FROM VIAJES AS VJ	WHERE VJ.IDCliente= CL.ID AND VJ.Inicio IS NOT NULL) AS 'TOTAL_VIAJES',(		SELECT COUNT(*) FROM VIAJES AS VJ	WHERE VJ.IDCliente= CL.ID AND VJ.Pagado=0 AND VJ.Inicio IS NOT NULL)AS 'TOTAL_NOPAGOS',(	SELECT SUM(VJ.Importe) FROM VIAJES AS VJ	WHERE VJ.IDCliente= CL.ID AND VJ.Pagado=0 AND VJ.Inicio IS NOT NULL)AS 'TOTAL_ADEUDADO'FROM Clientes AS CL)AS FINALWHERE TOTAL_NOPAGOS > (TOTAL_VIAJES/2) SELECT * FROM VW_CLIENTESDEUDORESSELECT COUNT (*) FROM VIAJES  AS VINNER JOIN Clientes AS C ON C.ID=V.IDClienteWHERE C.Apellidos='Tirone'--3) Realizar un procedimiento almacenado llamado SP_ChoferesEfectivo que reciba un
--año como parámetro y permita lista apellidos y nombres de los choferes que en ese
--año únicamente realizaron viajes que fueron abonados con la forma de pago
--'Efectivo'.
--NOTA: Es indistinto si el viaje fue pagado o no. Utilizar la fecha de inicio del viaje para
--determinar el año del mismo

ALTER PROC SP_CHOFERESEFECTIVO (
	@INICIO INT
) 
AS
BEGIN

SELECT FINAL.Apellidos,FINAL.Nombres FROM (
	SELECT CH.Apellidos,CH.Nombres,
	(
		SELECT  COUNT (*) FROM VIAJES AS VJ
		INNER JOIN FormasPago AS FP  ON VJ.FormaPago=FP.ID
		WHERE YEAR(VJ.Inicio)=@INICIO AND FP.Nombre ='Efectivo' AND CH.ID= VJ.IDChofer 
	
		
	) AS 'TOTAL_EFECTIVO',
	
	(
		SELECT  COUNT (*) FROM VIAJES AS VJ
		INNER JOIN FormasPago AS FP  ON VJ.FormaPago=FP.ID
		WHERE YEAR(VJ.Inicio)=@INICIO AND FP.Nombre <> 'Efectivo' AND CH.ID= VJ.IDChofer 
	

	)AS 'TOTAL_OTROS'
	FROM CHOFERES AS CH

) AS  FINAL
WHERE TOTAL_EFECTIVO>0 AND TOTAL_OTROS=0
END

EXEC SP_CHOFERESEFECTIVO 2021

SELECT * FROM Choferes  C
JOIN Viajes  V ON V.IDChofer=C.ID
JOIN FormasPago F ON F.ID=V.FormaPago
WHERE V.Inicio IS NOT NULL


CREATE PROC SP_BRIAN (
@anio int
)
as
select c.id, c.Apellidos, c.Nombres
from Choferes as c,
(select v.IDChofer, count(*) cantidad from Viajes v inner join FormasPago f on v.FormaPago = f.ID 
    where year(v.Inicio) = @anio and f.Nombre = 'Efectivo' group by v.IDChofer) cantEfectivo,
(select v1.IDChofer, count(*) cantidad from Viajes v1 inner join FormasPago f on v1.FormaPago = f.ID 
    where year(v1.Inicio) = @anio and f.Nombre <> 'Efectivo' group by v1.IDChofer) cantDistintoEfectivo
where c.ID = cantEfectivo.IDChofer and c.ID = cantDistintoEfectivo.IDChofer and cantEfectivo.cantidad >0
and cantDistintoEfectivo.cantidad = 0

exec SP_BRIAN 2021

--4) Realizar un trigger que al borrar un cliente, primero quitarle todos los puntos (baja
--física) y establecer a NULL todos los viajes de ese cliente. Luego, eliminar
--físicamente el cliente de la base de datos

ALTER TRIGGER TR_ELIMINAR_CLIENTE ON CLIENTES
AFTER DELETE
AS
BEGIN
	BEGIN TRY
			BEGIN TRANSACTION -- USO TRANSACCIO YA QUE SON  3  CONSULTA DE ACCION QUE SE EJECUTAN
			DECLARE @IDCLIENTE BIGINT
			SELECT @IDCLIENTE= D.ID FROM deleted AS D

			--ELIMINO TODO LOS REGISTROS  DE LA TABLA DE PUNTOS

			DELETE FROM PUNTOS WHERE  IDCliente=@IDCLIENTE
			-- CAMBIO A NULL EL IDCLIENTE DE LA TABLA VIAJES
			UPDATE VIAJES SET IDCliente= NULL WHERE IDCliente=@IDCLIENTE
			--ELIMINO EL CLIENTE DE LA TABLA CLIENTES
			DELETE CLIENTES WHERE ID=@IDCLIENTE

			COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
		ROLLBACK
	END CATCH

END

--5) Realizar un trigger que garantice que el Cliente sólo pueda calificar al Chofer si el
--viaje se encuentra pagado. Caso contrario indicarlo con un mensaje aclaratorio.

CREATE TRIGGER TR_VALIDAR_CALIACION ON [PuntosChofer]
AFTER INSERT
AS
BEGIN

		DECLARE @ID_VIAJE BIGINT
		DECLARE @PAGO BIT

		SELECT @ID_VIAJE=IDViaje FROM inserted
		SELECT @PAGO=Pagado FROM Viajes WHERE ID=@ID_VIAJE

		IF(@PAGO=0)
		BEGIN
			ROLLBACK TRANSACTION
				PRINT('----------No se puedo calificar el chofer, por falta de pago----------------')
		END

		ELSE
		BEGIN
			PRINT('----------Gracias por calificar el viaje----------------')
		END


END