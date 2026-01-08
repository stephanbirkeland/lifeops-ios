"""Password hashing and verification using bcrypt"""

from passlib.context import CryptContext

# Configure bcrypt context with proper parameters
# rounds=12 provides good security/performance balance
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=12
)


def hash_password(password: str) -> str:
    """
    Hash a password using bcrypt.

    Args:
        password: Plain text password

    Returns:
        Hashed password string

    Examples:
        >>> hashed = hash_password("my_secure_password")
        >>> len(hashed) > 0
        True
    """
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plain password against a hashed password.

    Args:
        plain_password: Plain text password to verify
        hashed_password: Previously hashed password to check against

    Returns:
        True if password matches, False otherwise

    Examples:
        >>> hashed = hash_password("my_password")
        >>> verify_password("my_password", hashed)
        True
        >>> verify_password("wrong_password", hashed)
        False
    """
    return pwd_context.verify(plain_password, hashed_password)


def needs_update(hashed_password: str) -> bool:
    """
    Check if a hashed password needs to be rehashed with current settings.

    This is useful for upgrading password hashes when security parameters change.

    Args:
        hashed_password: Previously hashed password

    Returns:
        True if the hash should be updated, False otherwise
    """
    return pwd_context.needs_update(hashed_password)
