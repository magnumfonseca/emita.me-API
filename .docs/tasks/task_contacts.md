# CONTACTS

Follow the code guidelines I need to create the contact model that belongs to users

**important**: create specs first (TDD), and use shouldamatchers for model validations;

| Column name | type | validations |
|----------|----------|----------|
| ID  | UUID  | not null  |
| name  | string  | not null  |
| cpf  | string  | Brazilian CPF validation  |
| cnpj  | string  | Brazilian CNPJ validation  |
| phone  | string  |   |
| email  | string  | email validation  |
| user_id  | UUID  | not null  |

## VALIDATIONS

### CPF/CNPJ
CPF or CNPJ must be present
If CPF is present CNPJ is not mandatory
If CNPJ is present CPF is not mandatory

Both must have only numbers, but its a string because it could start with zero

valid CPF example: 012.345.678-90
valid CNPJ example: 00.394.460/0058-87

here you can search and find how to validate both: https://www.campuscode.com.br/conteudos/o-calculo-do-digito-verificador-do-cpf-e-do-cnpj

## Phone/Email
phone or email must be present
If phone is present email is not mandatory
If email is present phone is not mandatory

email must have a validation if it is a valid email

phone must have a validation if it is a valid phone

### Brazilian mobile phone validation

``` ruby
validates :cellphone,
          format: {
            with: /\A\d{2}9\d{8}\z/,
            message: "must contain DDD + 9 + 8 digits"
          }
```

Example formats this accepts
- 11987654321
- (11) 98765-4321
- 11 98765 4321
- 11-98765-4321
These patterns align with common Brazilian formats and match the regex patterns used in community examples.
