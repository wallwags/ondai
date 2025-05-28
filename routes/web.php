<?php

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

use Illuminate\Support\Facades\Route;
use Wave\Facades\Wave;

// Wave routes
Wave::routes();

Route::get('/', function () {
    return 'Hello from Laravel on Render!';
});
Route::get('/show-log', function () {
    return nl2br(file_get_contents(storage_path('logs/laravel.log')));
});
