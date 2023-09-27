#include <iostream>
#include <string>

struct Dimensions
{
    int length;
    int width;
    int height;
};

int input_dimension(std::string message);

float calc_volume(int &length, int &width, int &height);
float calc_volume(Dimensions &d);

int main()
{
    char const SENTINEL = 'N';

    Dimensions room{0, 0, 0};

    float gallons = 0.0;

    char sentinel_store = 'U';

    while (sentinel_store != SENTINEL)
    {
        system("clear");

        room.length = input_dimension("Please provide a length");
        room.width = input_dimension("Please provide a width");
        room.height = input_dimension("Please provide a height");

        gallons = calc_volume(room);

        std::cout << "Gallons required: " << gallons << "\n";
        std::cout << "Would you like to calculate for another room? Type 'N' if not\n";
        std::cin >> sentinel_store;
    }

    std::cout << "Thanks!";

    // system("pause");

    return 0;
}

int input_dimension(std::string message)
{
    std::string input = "";

    std::cout << message << ": ";
    std::cin >> input;

    return std::stoi(input);
}

float calc_volume(int &length, int &width, int &height)
{
    return (length + width) * height / 200.0;
}
float calc_volume(Dimensions &d)
{
    return calc_volume(d.length, d.width, d.height);
}
