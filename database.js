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
    const [result] = await pool.query("SELECT id, first_name, last_name, user_login FROM users");
    return result;
}

export async function getUser(id) {
    const [result] = await pool.query("SELECT * FROM users WHERE id = ?", [id]);
    return result[0];
}

const user = await getUser(100);
console.log(user);

const users = await getUsers();
console.log(users);
