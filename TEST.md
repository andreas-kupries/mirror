# Testing the mirror management

Notes:

   - This testsuite requires a working internet connection.

   - It requires access to the fossil and github repositories listed
     in the `REF` section of `tests/support/invoke.tcl`.

   - In the places where commands may generate mail either the inputs
     are chosen to not to, or an option is used to force
     non-generation of mail.

     This means that the mail-generating parts of the system are
     __not__ covered by the testsuite.

     Change this only when the testsuite is sandboxed to the point
     where generated mail cannot reach the actual internet.
