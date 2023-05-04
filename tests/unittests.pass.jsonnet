local utils = import '../utils.libsonnet';

// Basic unittesting for methods that are not exercised by the other e2e-ish tests
// spin.libsonnet
std.assertEqual(true, true) &&
std.assertEqual(utils.objectHasObject({}, {}), true) &&
std.assertEqual(utils.objectHasObject({ a: '1', b: '2' }, { a: '1', b: '2' }), true) &&
std.assertEqual(utils.objectHasObject({ a: '1', b: '2', c: '3' }, { a: '1', b: '2' }), true) &&
std.assertEqual(utils.objectHasObject({ a: '1', b: '2' }, { a: '1', b: '2', c: '3' }), false) &&
true
