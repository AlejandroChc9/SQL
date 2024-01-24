-- EXAMEN 2
-- Alejandro Chávez Caycho

/*1.- (7 puntos) Crear un Store procedure que permita insertar un Documento de Venta deberá validar lo siguiente:
1.1 Que el documento de venta no exista (validar según el primary key del documento venta)
1.2 Que el Código de Tipo de Documento Venta exista en la tabla TipoDocumentoVenta
1.3 Que el Código de Moneda a insertar exista en la tabla Moneda
1.4 Que el código de cliente a Insertar exista en la tabla Cliente
1.5 Que el subtotal sea un importe mayor a cero
1.6 Considerar los parámetros necesarios para insertar la Factura, NO considerar como parámetros :
 - RUC : tomará el valor del código del Cliente (codigocliente sí es parametro)
 -NombreCliente : será el nombre del Cliente de la tabla Cliente, buscarlo a partir del códigocliente que es un parámetro del store procedure.
 -DireccionCliente: será la Direccion del Cliente de la tabla Cliente , buscarlo a partir del codigocliente que es un parámetro del store procedure.
 -TipoCambio : colocar un valor fijo de cero (0)
 -IGV : es un campo calculado a partir del parámetro subtotal es: 18 % del subtotal
 -Total: es un campo calcualado es : la suma del subtotal + igv. */

CREATE PROCEDURE InsertarDocumentoVenta
    @CodigoTipoDocumento CHAR(2),
	@Serie VARCHAR(4),
	@NumeroDocumento VARCHAR(20),
    @CodigoMoneda VARCHAR(3),
    @CodigoCliente VARCHAR(20),
    @Subtotal NUMERIC(9, 2)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1.1 Validar que el documento de venta no exista
    IF EXISTS (SELECT 1 FROM DocumentoVenta WHERE CodigoTipoDocumento = @CodigoTipoDocumento AND Serie = @Serie AND NumeroDocumento = @NumeroDocumento )
    BEGIN
        THROW 50000, 'El documento de venta ya existe.', 1;
        RETURN;
    END;

    -- 1.2 Validar que el Código de Tipo de Documento Venta exista
    IF NOT EXISTS (SELECT 1 FROM TipoDocumento WHERE CodigoTipoDocumento = @CodigoTipoDocumento)
    BEGIN
        THROW 50000, 'El código de tipo de documento venta no existe.', 1;
        RETURN;
    END;

    -- 1.3 Validar que el Código de Moneda exista
    IF NOT EXISTS (SELECT 1 FROM Moneda WHERE CodigoMoneda = @CodigoMoneda)
    BEGIN
        THROW 50000, 'El código de moneda no existe.', 1;
        RETURN;
    END;

    -- 1.4 Validar que el Código de Cliente exista
    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE CodigoCliente = @CodigoCliente)
    BEGIN
        THROW 50000, 'El código de cliente no existe.', 1;
        RETURN;
    END;

    -- 1.5 Validar que el subtotal sea un importe mayor a cero
    IF @Subtotal <= 0
    BEGIN
        THROW 50000, 'El subtotal debe ser mayor a cero.', 1;
        RETURN;
    END;

    -- Obtener RUC, NombreCliente y DireccionCliente
    DECLARE @FechaDocumento DATE, @RUC VARCHAR(20), @NombreCliente VARCHAR(254), @DireccionCliente VARCHAR(200);

    SELECT @RUC = codigocliente, @NombreCliente = NombreCliente, @DireccionCliente = Direccion, @FechaDocumento = GETDATE()
    FROM Cliente
    WHERE CodigoCliente = @CodigoCliente;

    -- 1.6 Insertar el documento de venta
    INSERT INTO DocumentoVenta (
        CodigoTipoDocumento,
		FechaDocumento,
		Serie,
		NumeroDocumento,
        CodigoMoneda,
        CodigoCliente,
        RUC,
        NombreCliente,
        DireccionCliente,
        TipoCambio,
        Subtotal,
        IGV,
        Total
    )
    VALUES (
        @CodigoTipoDocumento,
		@FechaDocumento,
        @Serie,
		@NumeroDocumento,
        @CodigoMoneda,
        @CodigoCliente,
        @RUC,
        @NombreCliente,
        @DireccionCliente,
        0, -- TipoCambio
        @Subtotal,
        @Subtotal * 0.18, -- IGV (18% del subtotal)
        @Subtotal * 1.18 -- Total (subtotal + igv)
    );
END;

--Ejemplo:
-- Valores de prueba
DECLARE @CodigoTipoDocumento CHAR(2) = '07';
DECLARE @Serie VARCHAR(4) = '001';
DECLARE @NumeroDocumento VARCHAR(20) = '001-123456';
DECLARE @CodigoMoneda VARCHAR(3) = 'USD';
DECLARE @CodigoCliente VARCHAR(20) = '20522017133';
DECLARE @Subtotal NUMERIC(9, 2) = 100.00;

-- Llamada al procedimiento almacenado
EXEC InsertarDocumentoVenta
    @CodigoTipoDocumento,
    @Serie,
    @NumeroDocumento,
    @CodigoMoneda,
    @CodigoCliente,
    @Subtotal;

-- Consulta Documento insertado.
 SELECT * FROM DocumentoVenta
	 WHERE
	 CodigoTipoDocumento = '07' AND 
	 Serie = '001' AND 
	 NumeroDocumento = '001-123456' AND 
	 CodigoMoneda = 'USD' AND 
	 CodigoCliente = '20522017133' AND 
	 Subtotal = 100.00

/*2.- (6 puntos) Crear un store procedure que permita modificar un servicio (Un registro)
de la Tabla DocumentoVentaDetalle los campos a modificar son :subtotal , igv, total
2.1 Parametros : CodigoTipoDocumento, serie, numeroDocumento, CodigoServicio, subtotal(importe nuevo que tomará el subtotal),
igv (importe nuevo que tomara el igv ), total (importe nuevo que tomará el total)
2.2 A partir de estos cuatro parametros CodigoTipoDocumento, serie, numeroDocumento, CodigoServicio,se podrá realizar la modificación del subtotal, igv y total.
2.3- A partir de la modificación de este servicio actualizar el monto subtotal, igv, total de la tabla DocumentoVenta.
Nota: Como se ha visto en clase el Documento de Venta Detalle contiene todos los servicios cuya suma de subtotales da como 
resultado el valor subtotal de la Tabla Documento de Venta, esto aplica también para el igv y el total.*/

CREATE PROCEDURE ModificarServicioDocumentoVenta
    @CodigoTipoDocumento CHAR(2),
	@Serie VARCHAR(4),
	@NumeroDocumento VARCHAR(20),
    @CodigoServicio INT,
    @NuevoSubtotal NUMERIC(9, 2),
    @NuevoIGV NUMERIC(9, 2),
    @NuevoTotal NUMERIC(9, 2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Actualizar el servicio en DocumentoVentaDetalle
    UPDATE DocumentoVentaDetalle
    SET Subtotal = @NuevoSubtotal,
        IGV = @NuevoIGV,
        Total = @NuevoTotal
    WHERE CodigoTipoDocumento = @CodigoTipoDocumento
        AND Serie = @Serie
        AND NumeroDocumento = @NumeroDocumento
        AND CodigoServicio = @CodigoServicio;

    -- Actualizar los montos en DocumentoVenta
    UPDATE dv
    SET dv.Subtotal = ISNULL(dvs.Subtotal, 0),
        dv.IGV = ISNULL(dvs.IGV, 0),
        dv.Total = ISNULL(dvs.Total, 0)
    FROM DocumentoVenta dv
    INNER JOIN (
        SELECT
            d.CodigoTipoDocumento,
            d.Serie,
            d.NumeroDocumento,
            SUM(d.Subtotal) AS Subtotal,
            SUM(d.IGV) AS IGV,
            SUM(d.Total) AS Total
        FROM DocumentoVentaDetalle d
        WHERE d.CodigoTipoDocumento = @CodigoTipoDocumento
            AND d.Serie = @Serie
            AND d.NumeroDocumento = @NumeroDocumento
        GROUP BY
            d.CodigoTipoDocumento,
            d.Serie,
            d.NumeroDocumento
    ) AS dvs ON dv.CodigoTipoDocumento = dvs.CodigoTipoDocumento
                AND dv.Serie = dvs.Serie
                AND dv.NumeroDocumento = dvs.NumeroDocumento
    WHERE dv.CodigoTipoDocumento = @CodigoTipoDocumento
        AND dv.Serie = @Serie
        AND dv.NumeroDocumento = @NumeroDocumento;

    -- (Opcional) Puedes devolver algún mensaje o resultado
    SELECT 'Servicio modificado exitosamente.' AS Resultado;
END;


--Ejemplo:
-- Definición de valores de prueba
DECLARE @CodigoTipoDocumento CHAR(2) = '01';
DECLARE @Serie VARCHAR(4) = '001';
DECLARE @NumeroDocumento VARCHAR(20) = '001-131959';
DECLARE @CodigoServicio INT = '000096';
DECLARE @NuevoSubtotal NUMERIC(9, 2) = 200.00;
DECLARE @NuevoIGV NUMERIC(9, 2) = 36.00;
DECLARE @NuevoTotal NUMERIC(9, 2) = 236.00;

-- Llamada al procedimiento almacenado
EXEC ModificarServicioDocumentoVenta
    @CodigoTipoDocumento,
    @Serie,
    @NumeroDocumento,
    @CodigoServicio,
    @NuevoSubtotal,
    @NuevoIGV,
    @NuevoTotal;

--Consulta:
SELECT*FROM DocumentoVentaDetalle
WHERE CodigoTipoDocumento = '01'AND Serie = '001' AND NumeroDocumento = '001-131959';

select*from DocumentoVenta
WHERE CodigoTipoDocumento = '01'AND Serie = '001' AND NumeroDocumento = '001-131959'

/*3.- (7 puntos) Crear un Store Procedure que tome en consideración lo siguiente:
3.1.-El store procedure debe insertar 1 registro en la tabla Documento de Venta, considerar los parámetros necesarios.
3.2.-Al insertar un Documento de Venta no es necesario insertar datos en la Tabla DocumentoVentaDetalle.
3.3.-Deberá crear la siguiente tabla LineaCreditoCliente con los siguientes campos:
-CodigoCliente : Es el codigoCliente al cual se le dará una línea de Credito
-ImporteLineaCredito: Es el importe de la línea de crédito que se concede al cliente.
-CodigoMoneda: Es el Codigo de Moneda PEN o USD de la Línea Crédito
3.4.-Insertar algunos datos de ejemplo en la Tabla LineaCreditoCliente para que pueda validar su Store Procedure (Como CodigoCliente 
considerar a los que después se les insertará en un documento de venta. Para sus nuevos Documentos de Venta, pueden copiar datos de la 
tabla Documento Venta de Documentos de Venta existentes, pero deberán cambiarle el número de documento para evitar la restricción de primary key)
3.5.- La regla de negocio que tiene el Store Procedure es que cada vez que se inserte una venta (Tabla DocumentoVenta), el Store Procedure se
encargará de descontar el valor subtotal al importeLineaCredito de la Tabla LineaCredito, tomando en cuenta la moneda.
Ejemplo el cliente X tiene un Importe de línea de Crédito de 10 000 Soles, se le emite al Cliente una factura por un monto de 1000 Soles.
El Nuevo importe de Línea de Crédito será 9000 Soles
3.6.-La  Linea Credito de crédito del Cliente se reducirá siempre y cuando coincidan las monedas de Factura y Linea de Credito.
Ejemplo: Factura en Soles , Linea de Credito en Soles.
3.7 En caso de no encontrar Linea de Credito para el cliente segun la moneda de la Factura,
el store proceso no realizará ningúna actualización a la Linea de Credito.*/

-- Crear la tabla LineaCreditoCliente
CREATE TABLE LineaCreditoCliente (
    CodigoCliente VARCHAR(20) PRIMARY KEY,
    ImporteLineaCredito NUMERIC(9, 2),
    CodigoMoneda VARCHAR(3)
);

-- Insertar algunos datos de ejemplo en la tabla LineaCreditoCliente
INSERT INTO LineaCreditoCliente (CodigoCliente, ImporteLineaCredito, CodigoMoneda)
VALUES
    ('20432087132', 10000.00, 'PEN'),
    ('20522017133', 8000.00, 'USD');

-- Crear el procedimiento almacenado
CREATE PROCEDURE InsertarDocumentoVentaYActualizarLineaCredito
    @CodigoTipoDocumento CHAR(2),
	@Serie VARCHAR(4),
	@NumeroDocumento VARCHAR(20),
    @CodigoMonedaDocumento VARCHAR(3),
    @CodigoCliente VARCHAR(20),
    @Subtotal NUMERIC(9, 2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Obtener RUC, NombreCliente y DireccionCliente
    DECLARE @FechaDocumento DATE, @RUC VARCHAR(20), @NombreCliente VARCHAR(254), @DireccionCliente VARCHAR(200);

    SELECT @RUC = codigocliente, @NombreCliente = NombreCliente, @DireccionCliente = Direccion, @FechaDocumento = GETDATE()
    FROM Cliente
    WHERE CodigoCliente = @CodigoCliente;

    -- 3.2 Insertar un registro en la tabla DocumentoVenta
    INSERT INTO DocumentoVenta (
        CodigoTipoDocumento,
		Serie,
		NumeroDocumento,
        CodigoMoneda,
		TipoCambio,
        CodigoCliente,
		NombreCliente,
		DireccionCliente,
        Ruc,
        Subtotal,
        IGV,
        Total,
        FechaDocumento
    )

    VALUES (
        @CodigoTipoDocumento,
        @Serie,
		@NumeroDocumento,
        @CodigoMonedaDocumento,
		0,--Tipo de cambio
        @CodigoCliente,
		@NombreCliente,
		@DireccionCliente,
        @RUC,
        @Subtotal,
        @Subtotal * 0.18, -- IGV (18% del subtotal)
        @Subtotal * 1.18, -- Total (subtotal + igv)
        GETDATE()
    );

    -- 3.5 Actualizar la LineaCreditoCliente si existe
    UPDATE LineaCreditoCliente
    SET ImporteLineaCredito = ImporteLineaCredito - @Subtotal
    WHERE CodigoCliente = @CodigoCliente AND CodigoMoneda = @CodigoMonedaDocumento
        AND ImporteLineaCredito >= @Subtotal;
END;


-- Llamada al procedimiento almacenado
EXEC InsertarDocumentoVentaYActualizarLineaCredito
    @CodigoTipoDocumento = '01',
    @Serie = '001',
    @NumeroDocumento = '001-123458',
    @CodigoMonedaDocumento = 'USD',
    @CodigoCliente = '20432087132',
    @Subtotal = 1000.00;


--Consulta
SELECT * FROM Lineacreditocliente

select * from DocumentoVenta
where CodigoTipoDocumento = '01' AND Serie = '001' AND NumeroDocumento = '001-123458' and CodigoMoneda = 'PEN'