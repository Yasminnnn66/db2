USE db_techmarket;


CREATE OR REPLACE VIEW vw_vendas_detalhadas AS
SELECT
    i.id_item,
    pe.id_pedido,
    pe.data_pedido,
    c.id_cliente,
    c.nome AS cliente,
    c.cidade,
    c.estado,
    v.id_vendedor,
    v.nome AS vendedor,
    v.equipe,
    pr.id_produto,
    pr.descricao AS produto,
    pr.categoria,
    i.quantidade,
    i.preco_unitario,
    i.desconto_percentual,
    ROUND(i.quantidade * i.preco_unitario, 2) AS valor_bruto,
    ROUND(i.quantidade * i.preco_unitario * i.desconto_percentual / 100, 2)
        AS valor_desconto,
    ROUND(
        i.quantidade * i.preco_unitario
        - ROUND(i.quantidade * i.preco_unitario * i.desconto_percentual / 100, 2),
        2
    ) AS valor_faturado
FROM pedidos AS pe
JOIN clientes AS c ON c.id_cliente = pe.id_cliente
JOIN vendedores AS v ON v.id_vendedor = pe.id_vendedor
JOIN itens_pedido AS i ON i.id_pedido = pe.id_pedido
JOIN produtos AS pr ON pr.id_produto = i.id_produto
WHERE pe.status_pedido = 'Faturado';


SELECT *
FROM vw_vendas_detalhadas
ORDER BY valor_faturado DESC, id_pedido, id_item;


SELECT id_pedido, cliente, produto, valor_faturado
FROM vw_vendas_detalhadas
ORDER BY valor_faturado DESC, id_pedido, id_item
LIMIT 5;


SELECT id_pedido, data_pedido, cliente, cidade, produto,
       quantidade, valor_faturado
FROM vw_vendas_detalhadas
WHERE estado = 'PR'
ORDER BY data_pedido ASC, id_pedido, id_item;


CREATE OR REPLACE VIEW vw_desempenho_vendedores AS
SELECT
    v.id_vendedor,
    v.nome AS vendedor,
    v.equipe,
    COUNT(DISTINCT d.id_pedido) AS pedidos_faturados,
    COALESCE(SUM(d.quantidade), 0) AS unidades_vendidas,
    COALESCE(ROUND(SUM(d.valor_faturado), 2), 0) AS faturamento_total
FROM vendedores AS v
LEFT JOIN vw_vendas_detalhadas AS d ON d.id_vendedor = v.id_vendedor
GROUP BY v.id_vendedor, v.nome, v.equipe;


SELECT vendedor, equipe, pedidos_faturados, unidades_vendidas,
       faturamento_total,
       CASE WHEN pedidos_faturados > 0
            THEN ROUND(faturamento_total / pedidos_faturados, 2)
            ELSE 0 END AS ticket_medio_pedido
FROM vw_desempenho_vendedores
ORDER BY faturamento_total DESC, vendedor;


SELECT equipe,
       SUM(pedidos_faturados) AS pedidos_faturados,
       ROUND(SUM(faturamento_total), 2) AS faturamento_total
FROM vw_desempenho_vendedores
GROUP BY equipe
ORDER BY faturamento_total DESC;


CREATE OR REPLACE VIEW vw_desempenho_produtos AS
SELECT
    pr.id_produto,
    pr.descricao AS produto,
    pr.categoria,
    COALESCE(SUM(d.quantidade), 0) AS unidades_vendidas,
    COUNT(DISTINCT d.id_pedido) AS pedidos_faturados,
    COALESCE(ROUND(SUM(d.valor_faturado), 2), 0) AS faturamento_total
FROM produtos AS pr
LEFT JOIN vw_vendas_detalhadas AS d ON d.id_produto = pr.id_produto
GROUP BY pr.id_produto, pr.descricao, pr.categoria;


SELECT produto, categoria, unidades_vendidas, faturamento_total
FROM vw_desempenho_produtos
ORDER BY faturamento_total DESC, produto;


SELECT categoria,
       SUM(unidades_vendidas) AS unidades_vendidas,
       ROUND(SUM(faturamento_total), 2) AS faturamento_total
FROM vw_desempenho_produtos
GROUP BY categoria
HAVING SUM(faturamento_total) > 2000
ORDER BY faturamento_total DESC;


SELECT produto, categoria, unidades_vendidas,
       ROUND(faturamento_total / unidades_vendidas, 2)
           AS valor_medio_faturado_por_unidade
FROM vw_desempenho_produtos
WHERE unidades_vendidas > 0
ORDER BY valor_medio_faturado_por_unidade DESC, produto
LIMIT 3;


CREATE OR REPLACE VIEW vw_resumo_clientes AS
SELECT
    c.id_cliente,
    c.nome AS cliente,
    c.cidade,
    c.estado,
    COUNT(DISTINCT d.id_pedido) AS pedidos_faturados,
    COALESCE(ROUND(SUM(d.valor_faturado), 2), 0) AS faturamento_total
FROM clientes AS c
LEFT JOIN vw_vendas_detalhadas AS d ON d.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nome, c.cidade, c.estado;


SELECT cliente, cidade, estado, pedidos_faturados,
       faturamento_total,
       CASE WHEN pedidos_faturados > 0
            THEN ROUND(faturamento_total / pedidos_faturados, 2)
            ELSE 0 END AS ticket_medio_pedido
FROM vw_resumo_clientes
ORDER BY faturamento_total DESC, cliente;


SELECT cliente, estado, pedidos_faturados, faturamento_total,
       CASE
           WHEN faturamento_total >= 5000 THEN 'VIP'
           WHEN faturamento_total > 0 THEN 'Regular'
           ELSE 'Sem compras'
       END AS classificacao
FROM vw_resumo_clientes
ORDER BY faturamento_total DESC, cliente;


SELECT estado,
       COUNT(*) AS clientes_cadastrados,
       ROUND(SUM(faturamento_total), 2) AS faturamento_total,
       ROUND(AVG(faturamento_total), 2) AS media_por_cliente
FROM vw_resumo_clientes
GROUP BY estado
ORDER BY faturamento_total DESC;


SELECT v.equipe,
       SUM(v.pedidos_faturados) AS pedidos_faturados,
       ROUND(SUM(COALESCE(d.receita_vendedor, 0)), 2) AS faturamento_total,
       CASE WHEN SUM(v.pedidos_faturados) > 0
            THEN ROUND(SUM(COALESCE(d.receita_vendedor, 0))
                       / SUM(v.pedidos_faturados), 2)
            ELSE 0 END AS ticket_medio_equipe
FROM vw_desempenho_vendedores AS v
LEFT JOIN (
    SELECT id_vendedor, SUM(valor_faturado) AS receita_vendedor
    FROM vw_vendas_detalhadas
    GROUP BY id_vendedor
) AS d ON d.id_vendedor = v.id_vendedor
GROUP BY v.equipe
ORDER BY faturamento_total DESC;


SELECT p.categoria,
       ROUND(SUM(p.faturamento_total), 2) AS faturamento_total,
       CASE WHEN t.faturamento_empresa > 0
            THEN ROUND(SUM(p.faturamento_total) * 100
                       / t.faturamento_empresa, 2)
            ELSE 0 END AS participacao_percentual
FROM vw_desempenho_produtos AS p
CROSS JOIN (
    SELECT COALESCE(SUM(valor_faturado), 0) AS faturamento_empresa
    FROM vw_vendas_detalhadas
) AS t
GROUP BY p.categoria, t.faturamento_empresa
ORDER BY faturamento_total DESC;


SELECT c.cliente, c.estado, c.faturamento_total,
       ROUND(c.faturamento_total - m.media_clientes_ativos, 2)
           AS diferenca_para_media
FROM vw_resumo_clientes AS c
CROSS JOIN (
    SELECT AVG(x.total_cliente) AS media_clientes_ativos
    FROM (
        SELECT id_cliente, SUM(valor_faturado) AS total_cliente
        FROM vw_vendas_detalhadas
        GROUP BY id_cliente
    ) AS x
) AS m
WHERE c.pedidos_faturados > 0
  AND c.faturamento_total > m.media_clientes_ativos
ORDER BY diferenca_para_media DESC, c.cliente;


CREATE OR REPLACE VIEW vw_desempenho_vendedores AS
SELECT
    v.id_vendedor,
    v.nome AS vendedor,
    v.equipe,
    COUNT(DISTINCT d.id_pedido) AS pedidos_faturados,
    COALESCE(SUM(d.quantidade), 0) AS unidades_vendidas,
    COALESCE(ROUND(SUM(d.valor_faturado), 2), 0) AS faturamento_total,
    COALESCE(ROUND(SUM(d.valor_desconto), 2), 0) AS desconto_total
FROM vendedores AS v
LEFT JOIN vw_vendas_detalhadas AS d ON d.id_vendedor = v.id_vendedor
GROUP BY v.id_vendedor, v.nome, v.equipe;


SELECT vendedor, equipe, pedidos_faturados, unidades_vendidas,
       faturamento_total, desconto_total
FROM vw_desempenho_vendedores
ORDER BY desconto_total DESC, vendedor;


SELECT *
FROM vw_vendas_detalhadas
ORDER BY valor_faturado DESC, id_pedido, id_item;


SELECT id_pedido, cliente, produto, valor_faturado
FROM vw_vendas_detalhadas
ORDER BY valor_faturado DESC, id_pedido, id_item
LIMIT 5;


SELECT id_pedido, data_pedido, cliente, cidade, produto,
       quantidade, valor_faturado
FROM vw_vendas_detalhadas
WHERE estado = 'PR'
ORDER BY data_pedido ASC, id_pedido, id_item;


SELECT vendedor, equipe, pedidos_faturados, unidades_vendidas,
       faturamento_total,
       CASE WHEN pedidos_faturados > 0
            THEN ROUND(faturamento_total / pedidos_faturados, 2)
            ELSE 0 END AS ticket_medio_pedido
FROM vw_desempenho_vendedores
ORDER BY faturamento_total DESC, vendedor;


SELECT equipe,
       SUM(pedidos_faturados) AS pedidos_faturados,
       ROUND(SUM(faturamento_total), 2) AS faturamento_total
FROM vw_desempenho_vendedores
GROUP BY equipe
ORDER BY faturamento_total DESC;


SELECT produto, categoria, unidades_vendidas, faturamento_total
FROM vw_desempenho_produtos
ORDER BY faturamento_total DESC, produto;


SELECT categoria,
       SUM(unidades_vendidas) AS unidades_vendidas,
       ROUND(SUM(faturamento_total), 2) AS faturamento_total
FROM vw_desempenho_produtos
GROUP BY categoria
HAVING SUM(faturamento_total) > 2000
ORDER BY faturamento_total DESC;


SELECT produto, categoria, unidades_vendidas,
       ROUND(faturamento_total / unidades_vendidas, 2)
           AS valor_medio_faturado_por_unidade
FROM vw_desempenho_produtos
WHERE unidades_vendidas > 0
ORDER BY valor_medio_faturado_por_unidade DESC, produto
LIMIT 3;


SELECT cliente, cidade, estado, pedidos_faturados,
       faturamento_total,
       CASE WHEN pedidos_faturados > 0
            THEN ROUND(faturamento_total / pedidos_faturados, 2)
            ELSE 0 END AS ticket_medio_pedido
FROM vw_resumo_clientes
ORDER BY faturamento_total DESC, cliente;


SELECT cliente, estado, pedidos_faturados, faturamento_total,
       CASE
           WHEN faturamento_total >= 5000 THEN 'VIP'
           WHEN faturamento_total > 0 THEN 'Regular'
           ELSE 'Sem compras'
       END AS classificacao
FROM vw_resumo_clientes
ORDER BY faturamento_total DESC, cliente;


SELECT estado,
       COUNT(*) AS clientes_cadastrados,
       ROUND(SUM(faturamento_total), 2) AS faturamento_total,
       ROUND(AVG(faturamento_total), 2) AS media_por_cliente
FROM vw_resumo_clientes
GROUP BY estado
ORDER BY faturamento_total DESC;


SELECT v.equipe,
       SUM(v.pedidos_faturados) AS pedidos_faturados,
       ROUND(SUM(COALESCE(d.receita_vendedor, 0)), 2) AS faturamento_total,
       CASE WHEN SUM(v.pedidos_faturados) > 0
            THEN ROUND(SUM(COALESCE(d.receita_vendedor, 0))
                       / SUM(v.pedidos_faturados), 2)
            ELSE 0 END AS ticket_medio_equipe
FROM vw_desempenho_vendedores AS v
LEFT JOIN (
    SELECT id_vendedor, SUM(valor_faturado) AS receita_vendedor
    FROM vw_vendas_detalhadas
    GROUP BY id_vendedor
) AS d ON d.id_vendedor = v.id_vendedor
GROUP BY v.equipe
ORDER BY faturamento_total DESC;


SELECT p.categoria,
       ROUND(SUM(p.faturamento_total), 2) AS faturamento_total,
       CASE WHEN t.faturamento_empresa > 0
            THEN ROUND(SUM(p.faturamento_total) * 100
                       / t.faturamento_empresa, 2)
            ELSE 0 END AS participacao_percentual
FROM vw_desempenho_produtos AS p
CROSS JOIN (
    SELECT COALESCE(SUM(valor_faturado), 0) AS faturamento_empresa
    FROM vw_vendas_detalhadas
) AS t
GROUP BY p.categoria, t.faturamento_empresa
ORDER BY faturamento_total DESC;


SELECT c.cliente, c.estado, c.faturamento_total,
       ROUND(c.faturamento_total - m.media_clientes_ativos, 2)
           AS diferenca_para_media
FROM vw_resumo_clientes AS c
CROSS JOIN (
    SELECT AVG(x.total_cliente) AS media_clientes_ativos
    FROM (
        SELECT id_cliente, SUM(valor_faturado) AS total_cliente
        FROM vw_vendas_detalhadas
        GROUP BY id_cliente
    ) AS x
) AS m
WHERE c.pedidos_faturados > 0
  AND c.faturamento_total > m.media_clientes_ativos
ORDER BY diferenca_para_media DESC, c.cliente;


SELECT
    COUNT(DISTINCT id_pedido) AS total_pedidos_faturados,
    COUNT(*) AS total_itens_faturados,
    ROUND(SUM(valor_bruto), 2) AS valor_bruto_total,
    ROUND(SUM(valor_desconto), 2) AS desconto_total,
    ROUND(SUM(valor_faturado), 2) AS faturamento_total
FROM vw_vendas_detalhadas;

SELECT
    (SELECT SUM(faturamento_total)
       FROM vw_desempenho_vendedores) AS total_vendedores,
    (SELECT SUM(faturamento_total)
       FROM vw_desempenho_produtos) AS total_produtos,
    (SELECT SUM(faturamento_total)
       FROM vw_resumo_clientes) AS total_clientes;
