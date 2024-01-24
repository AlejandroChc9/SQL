--Procedimiento InsertarDocumentoVenta:

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

--Procedimiento ModificarServicioDocumentoVenta:

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

-- Pruebas
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

--Pruebas:
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
