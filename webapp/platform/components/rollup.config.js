// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import commonjs from '@rollup/plugin-commonjs';
import resolve from '@rollup/plugin-node-resolve';
import typescript from '@rollup/plugin-typescript';
import scss from 'rollup-plugin-scss';

import packagejson from './package.json';

const externals = [
    ...Object.keys(packagejson.dependencies || {}),
    ...Object.keys(packagejson.peerDependencies || {}),
    'lodash/throttle',
    'mattermost-redux',
    'reselect',
];

export default [
    {
        input: 'src/index.tsx',
        output: [
            {
                sourcemap: true,
                file: packagejson.module,
                format: 'es',
                globals: {'styled-components': 'styled'},
            },
        ],
        plugins: [
            scss({
                fileName: 'index.esm.css',
                outputToFilesystem: true,
            }),
            resolve({
                browser: true,
                extensions: ['.ts', '.tsx', '.js', '.jsx'],
            }),
            commonjs(),
            typescript({
                tsconfig: './tsconfig.json',
                outputToFilesystem: true,
                declaration: true,
                declarationDir: 'dist',
                exclude: ['**/*.test.ts', '**/*.test.tsx'],
            }),
        ],
        external: externals,
        watch: {
            clearScreen: false,
        },
    },
];
