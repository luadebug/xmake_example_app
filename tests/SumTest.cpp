#include <gmock/gmock.h>
#include "MainWindow.h"

TEST(Sum, AddsTwoIntegers) {
    EXPECT_EQ(MainWindow::sum(2, 2), 4);
}
