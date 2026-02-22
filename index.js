import express from 'express';
const app = express();

import {getUsers, getUser} from "./database.js";


app.get("/users", async (req, res) => {
    const users = await getUsers();
    res.json(users);
})

app.use((err, req, res, next) => {
    console.error(err.stack)
    res.status(500).send('Something broke!')
})

app.listen(8080, () => {
    console.log('Server is running on port 8080');
});

