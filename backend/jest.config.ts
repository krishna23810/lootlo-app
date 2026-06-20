import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts'],
  moduleNameMapper: {
    '^@common/(.*)$': '<rootDir>/src/common/$1',
    '^@auth/(.*)$': '<rootDir>/src/auth/$1',
    '^@game/(.*)$': '<rootDir>/src/game/$1',
    '^@ticket/(.*)$': '<rootDir>/src/ticket/$1',
    '^@wallet/(.*)$': '<rootDir>/src/wallet/$1',
    '^@draw/(.*)$': '<rootDir>/src/draw/$1',
    '^@signaling/(.*)$': '<rootDir>/src/signaling/$1',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.test.ts',
    '!src/**/index.ts',
  ],
};

export default config;
