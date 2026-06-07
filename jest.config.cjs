module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/handlers'],
  testMatch: ['**/*.test.ts'],
  transform: {
    '^.+\\.tsx?$': 'ts-jest',
  },
};
