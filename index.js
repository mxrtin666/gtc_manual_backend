import express from 'express';
import cors from 'cors';
import {
    getUsers, createUser, getUserByCredentials,
    getCountries, getCountry,
    getCurrencies,
    getRateRows,
    getTransactions, createTransaction
} from './database.js';

const app = express();

app.use(cors());
app.use(express.json());

// --- Countries ---

app.get('/countries', async (req, res) => {
    const countries = await getCountries();
    res.json(countries);
});

app.get('/countries/:iso', async (req, res) => {
    const country = await getCountry(req.params.iso);
    if (!country) {
        return res.status(404).json({ error: 'Country not found' });
    }
    res.json(country);
});

// --- Currencies ---

app.get('/currencies', async (req, res) => {
    const currencies = await getCurrencies();
    res.json(currencies);
});

// --- Rates ---

app.get('/rates', async (req, res) => {
    const rates = await getRateRows();
    res.json(rates);
});

// --- Auth ---

app.post('/login', async (req, res) => {
    const { userLogin, password } = req.body;
    if (!userLogin || !password) {
        return res.status(400).json({ error: 'userLogin and password are required' });
    }
    const user = await getUserByCredentials(userLogin, password);
    if (!user) {
        return res.status(401).json({ error: 'Invalid login or password' });
    }
    res.json(user);
});

// --- Users ---

app.get('/users', async (req, res) => {
    const users = await getUsers();
    res.json(users);
});

app.post('/users', async (req, res) => {
    const { firstName, lastName, userLogin, password } = req.body;
    if (!firstName || !lastName || !userLogin || !password) {
        return res.status(400).json({ error: 'All fields are required' });
    }
    try {
        const user = await createUser(firstName, lastName, userLogin, password);
        res.status(201).json(user);
    } catch (err) {
        if (err.code === 'ER_DUP_ENTRY') {
            return res.status(409).json({ error: 'User login already exists' });
        }
        throw err;
    }
});

// --- Transactions ---

app.get('/transactions', async (req, res) => {
    const transactions = await getTransactions();
    res.json(transactions);
});

app.post('/transactions', async (req, res) => {
    const { userLogin, sourceAmount, sourceCurrency, targetCurrency, exchangeRate, transactionDate } = req.body;
    if (!userLogin || !sourceAmount || !sourceCurrency || !targetCurrency || !exchangeRate || !transactionDate) {
        return res.status(400).json({ error: 'All fields are required' });
    }
    try {
        const transaction = await createTransaction(userLogin, sourceAmount, sourceCurrency, targetCurrency, exchangeRate, transactionDate);
        res.status(201).json(transaction);
    } catch (err) {
        if (err.message.startsWith('User not found')) {
            return res.status(400).json({ error: err.message });
        }
        throw err;
    }
});

// --- Error handler ---

app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something broke!' });
});

app.listen(8080, () => {
    console.log('Server is running on port 8080');
});
