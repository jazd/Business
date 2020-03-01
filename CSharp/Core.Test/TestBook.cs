using NUnit.Framework;

namespace Core.Test
{
    [TestFixture()]
    public class TestBook
    {
        [Test()]
        public void Empty() {
            var book = new Book();
        }
    }
}
