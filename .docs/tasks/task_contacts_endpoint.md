# Contacts endpoint

This is a rails 8 api, and I need to create a contacts endpoint
the front end expect tuple responses:
```json
// Success Response (200 OK or 201 Created)

{
  "success": true,
  "data": { "id": 1, "name": "Item" },
  "message": "Resource created successfully"
}

// Error Response (400 Bad Request, 422 Unprocessable Entity, etc.)
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is already taken",
    "details": ["Email is already taken"]
  }
}
```

All endpoints must be versioned in the route, eg. **api/v1/contacts**, and use **JSONAPI::Serializer** (gem jsonapi-serializer)
**Important**: Create specs first (TDD), and request specs must use rswag

## index
Returns the list of the contacts for the current user paginated using kaminari
It also must implement filter by name, cpf or cnpj

### Scenarios
1 - returns a list of contacts for the page 1
2 - returns a list of contacts for the page 2
3 - returns a empty list when the current user has no contacts
4 - return a list of contacts filtered by name
5 - return a list of contacts filtered by cpf
6 - return a list of contacts filtered by cnpj
7 - returns no contact when the filter does not have a match

## show
Returns the user for the correspondent id for the current_user

### Scenarios
1 - returns a contact
2 - returns error when contact is not found

## create
Create a contact for the current user

### Scenarios
1 - creates a contact with name, email, cpf
2 - creates a contact with name, phone, cnpj
3 - returns error when name is empty
4 - returns error when cpf and cnpj are empty
5 - returns error when email and phone are empty
6 - returns error when cpf is invalid
7 - returns error when cnpj is invalid

## destroy
Deletes a contact

### Scenarios
1 - returns success when deleting a found contact
2 - returns success when deleting a not found contact

# RSWag

run **rake rswag:specs:swaggerize** after every spec is passing

# Rubocop

run **rubocop** and fixes all issues