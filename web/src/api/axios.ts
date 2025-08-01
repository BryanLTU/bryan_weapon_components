import axios from 'axios';

const api = axios.create({
    baseURL: 'https://bryan_weapon_components/',
})

export default api;