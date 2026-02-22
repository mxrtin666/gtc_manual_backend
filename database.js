import mysql from "mysql2"
import dotenv from "dotenv"

dotenv.config()

const pool = mysql.createPool({
    host: process.env.MYSQLHOST,
    user: process.env.MYSQLUSER,
    password: process.env.MYSQLPASSWORD,
    database: process.env.MYSQLDATABASE
}).promise()

export async function getUsers() {
    const [rows] = await pool.query(
        `SELECT id,
                first_name AS firstName,
                last_name  AS lastName,
                user_login AS userLogin
         FROM users`
    );
    return rows;
}

export async function getUser(id) {
    const [rows] = await pool.query(
        `SELECT id,
                first_name AS firstName,
                last_name  AS lastName,
                user_login AS userLogin
         FROM users WHERE id = ?`, [id]
    );
    return rows[0];
}

export async function getUserByCredentials(login, password) {
    const [rows] = await pool.query(
        `SELECT id,
                first_name AS firstName,
                last_name  AS lastName,
                user_login AS userLogin
         FROM users
         WHERE user_login = ? AND password = ?`, [login, password]
    );
    return rows[0];
}

export async function getUserByLogin(userLogin) {
    const [rows] = await pool.query(
        `SELECT id,
                first_name AS firstName,
                last_name  AS lastName,
                user_login AS userLogin
         FROM users
         WHERE user_login = ?`, [userLogin]
    );
    return rows[0];
}

export async function createUser(firstName, lastName, userLogin, password) {
    const [result] = await pool.query(
        `INSERT INTO users (first_name, last_name, user_login, password)
         VALUES (?, ?, ?, ?)`,
        [firstName, lastName, userLogin, password]
    );
    return { id: result.insertId, firstName, lastName, userLogin };
}

export async function getCountries() {
    const [rows] = await pool.query(
        `SELECT c.iso,
                c.name,
                c.official,
                c.capital,
                c.largest_city   AS largestCity,
                c.area,
                c.area_rank      AS areaRank,
                c.population,
                c.population_rank AS populationRank,
                c.calling_code   AS callingCode,
                c.currency_iso   AS currencyIso,
                cur.name         AS currencyName,
                JSON_ARRAYAGG(t.tld) AS tld
         FROM countries c
                  JOIN currencies cur ON cur.iso = c.currency_iso
                  LEFT JOIN country_tlds t ON t.country_iso = c.iso
         GROUP BY c.iso
         ORDER BY c.iso`
    );
    return rows;
}

export async function getCountry(iso) {
    const [rows] = await pool.query(
        `SELECT c.iso,
                c.name,
                c.official,
                c.capital,
                c.largest_city   AS largestCity,
                c.area,
                c.area_rank      AS areaRank,
                c.population,
                c.population_rank AS populationRank,
                c.calling_code   AS callingCode,
                c.currency_iso   AS currencyIso,
                cur.name         AS currencyName,
                JSON_ARRAYAGG(t.tld) AS tld
         FROM countries c
                  JOIN currencies cur ON cur.iso = c.currency_iso
                  LEFT JOIN country_tlds t ON t.country_iso = c.iso
         WHERE c.iso = ?
         GROUP BY c.iso`, [iso]
    );
    return rows[0];
}

export async function getCurrencies() {
    const [rows] = await pool.query(
        `SELECT cur.iso,
                cur.name,
                JSON_ARRAYAGG(c.name) AS countries
         FROM currencies cur
                  LEFT JOIN countries c ON c.currency_iso = cur.iso
         GROUP BY cur.iso
         ORDER BY cur.iso`
    );
    return rows;
}

export async function getRateRows() {
    const [rows] = await pool.query(
        `SELECT base_currency_iso AS base,
                quote_currency_iso AS quote,
                rate
         FROM exchange_rates
         WHERE valid_to IS NULL`
    );

    const rowMap = new Map();
    for (const r of rows) {
        if (!rowMap.has(r.base)) {
            rowMap.set(r.base, { from: r.base });
        }
        rowMap.get(r.base)[r.quote] = parseFloat(r.rate);
    }
    return Array.from(rowMap.values());
}

export async function getTransactions() {
    const [rows] = await pool.query(
        `SELECT t.id,
                t.transaction_date  AS transactionDate,
                u.user_login        AS userLogin,
                t.source_amount     AS sourceAmount,
                t.source_currency_iso AS sourceCurrency,
                t.target_currency_iso AS targetCurrency,
                t.exchange_rate     AS exchangeRate
         FROM transactions t
                  JOIN users u ON u.id = t.user_id
         ORDER BY t.transaction_date DESC`
    );
    return rows;
}

export async function createTransaction(userLogin, sourceAmount, sourceCurrency, targetCurrency, exchangeRate, transactionDate) {
    const user = await getUserByLogin(userLogin);
    if (!user) {
        throw new Error('User not found: ' + userLogin);
    }
    const mysqlDate = new Date(transactionDate).toISOString().slice(0, 23).replace('T', ' ');
    const [result] = await pool.query(
        `INSERT INTO transactions (transaction_date, user_id, source_amount, source_currency_iso, target_currency_iso, exchange_rate)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [mysqlDate, user.id, sourceAmount, sourceCurrency, targetCurrency, exchangeRate]
    );
    return {
        id: result.insertId,
        transactionDate,
        userLogin,
        sourceAmount,
        sourceCurrency,
        targetCurrency,
        exchangeRate
    };
}
