package main

func queries() {
	// language=SQL
	query := `
    SELECT p.id, p.name
    FROM products AS p
    WHERE p.id = $1
`
	// language=SQL
	other := `SELECT p. FROM payments p`
	// language=SQL
	third := `SELECT p. FROM products p`
	// language=SQL
	tables := `SELECT * FROM pro`
	plain := `SELECT * FROM pro`
	outside := products
	_ = query
	_ = other
	_ = third
	_ = tables
	_ = plain
	_ = outside
}
