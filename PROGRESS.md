# DAY 1

Initialize project
Clean up unneccessary file
Add some base library (grape api)
Implement base API structure to test like helloworld
Design database Schema for authentication & authorization with tables:
  users: client/admin role
  clients client role and client information
  use has_secure_password built-in function in ActiveRecord. From the helper method it has around 3 attributes and some auto validation:
    password (non-db column): store raw string function from user input
    password_confirmation (non-db column): confirm same value with password
    password_digest (db-column): Rails automatically hashes raw string and saves as secure string
    validation: on presence, confirmation of password and maximum byte length of password (<=72)
Design implementation strategies with handwritten and draw (excalidraw.com) and save link in the DESIGN.md

# DAY 2
