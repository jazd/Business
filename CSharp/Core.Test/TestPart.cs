using NUnit.Framework;
using System;
using Core;
namespace Core.Test
{
    [TestFixture()]
    public class TestPart
    {
        [Test()]
        public void Empty() {
            var part = new Part();
        }
    }
}
